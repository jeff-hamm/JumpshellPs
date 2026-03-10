import { createHash } from 'node:crypto';
import { execFile } from 'node:child_process';
import { promises as fs } from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { promisify } from 'node:util';
import * as vscode from 'vscode';

type SkillManifestEntry = {
  name: string;
  relativePath: string;
  hash: string;
  fileCount: number;
};

type SkillSource = {
  kind: 'assets' | 'repo';
  rootPath: string;
  manifestPath?: string;
};

type AiBackendsSource = {
  kind: SkillSource['kind'];
  rootPath: string;
  editable: boolean;
};

type InstalledSkill = {
  hash: string;
  relativePath: string;
};

type InstalledAiBackends = {
  hash: string;
  installMode: 'regular' | 'editable';
  installStatus: 'ok' | 'failed';
  pipCommand?: string;
  error?: string;
  /** @deprecated Kept only so we can clean up old copy-based installs. */
  targetDir?: string;
};

type ManagedAiBackendsResult = {
  entry: InstalledAiBackends;
  summary: string;
};

type InstallReceipt = {
  extensionVersion: string;
  installedAt: string;
  sourceKind: SkillSource['kind'];
  targetDir: string;
  skills: Record<string, InstalledSkill>;
  aiBackends?: InstalledAiBackends;
};

type EditorVariant = 'code' | 'code-insiders' | 'cursor' | 'vscodium' | 'unknown';
type EditorInstallName = 'Code' | 'Code - Insiders' | 'Cursor' | 'VSCodium';

const receiptFileName = 'install-receipt.json';
const mcpTemplateFileName = 'jumpshellps.json';
const autoSetupVersionStateKey = 'autoSetupVersion';
const ignoredNames = new Set(['__pycache__', '.DS_Store', 'Thumbs.db']);
const ignoredExtensions = new Set(['.bak', '.pyc', '.pyo', '.egg-info']);
const execFileAsync = promisify(execFile);

let outputChannel: vscode.OutputChannel;

export function activate(context: vscode.ExtensionContext) {
  outputChannel = vscode.window.createOutputChannel('JumpShell');
  context.subscriptions.push(outputChannel);

  registerCommand(context, 'jumpshell.updateSkills', () => installManagedSkills(context, 'update'));
  registerCommand(context, 'jumpshell.installMcpConfig', () => installMcpConfig(context));
  void runAutoSetup(context);
}

export function deactivate() {
  outputChannel?.dispose();
}

function registerCommand(context: vscode.ExtensionContext, command: string, handler: () => Promise<void>) {
  const disposable = vscode.commands.registerCommand(command, async () => {
    try {
      await handler();
    }
    catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      outputChannel.appendLine(`[error] ${message}`);
      void vscode.window.showErrorMessage(`JumpShell: ${message}`);
    }
  });

  context.subscriptions.push(disposable);
}

async function runAutoSetup(context: vscode.ExtensionContext) {
  const extensionVersion = String(context.extension.packageJSON.version ?? '0.0.0');
  const completedVersion = context.globalState.get<string>(autoSetupVersionStateKey);
  if (completedVersion === extensionVersion) {
    return;
  }

  try {
    await installManagedSkills(context, 'install', {
      silent: true,
      conflictBehavior: 'skip',
      skipConfiguredMcpInstall: true
    });

    await installMcpConfig(context, {
      silent: true,
      allowPathPrompt: false
    });

    outputChannel.appendLine(`[startup] Auto-setup completed for version ${extensionVersion}.`);
  }
  catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    outputChannel.appendLine(`[warn] Auto-setup failed: ${message}`);
  }
  finally {
    await context.globalState.update(autoSetupVersionStateKey, extensionVersion);
  }
}

type InstallSkillsOptions = {
  silent?: boolean;
  conflictBehavior?: 'prompt' | 'skip' | 'overwrite';
  skipConfiguredMcpInstall?: boolean;
};

async function installManagedSkills(context: vscode.ExtensionContext, mode: 'install' | 'update', options: InstallSkillsOptions = {}) {
  const skillSource = await resolveSkillSource(context);
  const manifest = await loadManifest(skillSource);
  if (manifest.length === 0) {
    throw new Error(`No skills were found in ${skillSource.rootPath}.`);
  }

  const targetDir = resolveTargetSkillsDir();
  await fs.mkdir(targetDir, { recursive: true });

  const existingReceipt = await loadReceipt(context);
  const currentSkillNames = new Set(manifest.map((entry) => entry.name));
  const staleSkillNames = Object.keys(existingReceipt?.skills ?? {}).filter((skillName) => !currentSkillNames.has(skillName));

  const conflicts = [] as string[];
  for (const entry of manifest) {
    const targetSkillDir = path.join(targetDir, entry.relativePath);
    const targetExists = await pathExists(targetSkillDir);
    const installedSkill = existingReceipt?.skills[entry.name];
    const isManaged = Boolean(installedSkill && installedSkill.relativePath === entry.relativePath);
    const isAlreadyCurrent = Boolean(isManaged && installedSkill?.hash === entry.hash && targetExists);
    if (isAlreadyCurrent) {
      continue;
    }

    if (targetExists && !isManaged) {
      conflicts.push(entry.name);
    }
  }

  const conflictBehavior = options.conflictBehavior ?? 'prompt';
  let overwriteConflicts = conflictBehavior === 'overwrite';
  let skipConflicts = conflictBehavior === 'skip';

  if (conflicts.length > 0 && conflictBehavior === 'prompt') {
    const choice = await vscode.window.showWarningMessage(
      `JumpShell found ${conflicts.length} existing skill folder(s) that are not marked as extension-managed.`,
      { modal: true },
      'Overwrite',
      'Skip conflicts',
      'Cancel'
    );

    if (!choice || choice === 'Cancel') {
      return;
    }

    overwriteConflicts = choice === 'Overwrite';
    skipConflicts = choice === 'Skip conflicts';
  }

  const installedSkills: Record<string, InstalledSkill> = {};
  let installedCount = 0;
  let updatedCount = 0;
  let skippedCount = 0;
  let removedStaleCount = 0;

  if (existingReceipt) {
    for (const staleSkillName of staleSkillNames) {
      const staleSkill = existingReceipt.skills[staleSkillName];
      const stalePath = path.join(existingReceipt.targetDir, staleSkill.relativePath);
      if (await pathExists(stalePath)) {
        await fs.rm(stalePath, { recursive: true, force: true });
        outputChannel.appendLine(`[remove] ${stalePath}`);
        removedStaleCount += 1;
      }
    }
  }

  for (const entry of manifest) {
    const sourceSkillDir = path.join(skillSource.rootPath, entry.relativePath);
    const targetSkillDir = path.join(targetDir, entry.relativePath);
    const targetExists = await pathExists(targetSkillDir);
    const previouslyInstalled = existingReceipt?.skills[entry.name];
    const isManaged = Boolean(previouslyInstalled && previouslyInstalled.relativePath === entry.relativePath);
    const isAlreadyCurrent = Boolean(isManaged && previouslyInstalled?.hash === entry.hash && targetExists);

    if (isAlreadyCurrent) {
      installedSkills[entry.name] = {
        hash: entry.hash,
        relativePath: entry.relativePath
      };
      skippedCount += 1;
      continue;
    }

    if (targetExists && !isManaged && skipConflicts) {
      outputChannel.appendLine(`[skip] ${targetSkillDir}`);
      skippedCount += 1;
      continue;
    }

    if (targetExists && (!isManaged || overwriteConflicts || previouslyInstalled)) {
      await fs.rm(targetSkillDir, { recursive: true, force: true });
    }

    await copyDirectory(sourceSkillDir, targetSkillDir);
    installedSkills[entry.name] = {
      hash: entry.hash,
      relativePath: entry.relativePath
    };

    if (isManaged) {
      updatedCount += 1;
      outputChannel.appendLine(`[update] ${targetSkillDir}`);
    }
    else {
      installedCount += 1;
      outputChannel.appendLine(`[install] ${targetSkillDir}`);
    }
  }

  const installAiBackends = vscode.workspace.getConfiguration('jumpshell').get<boolean>('installAiBackendsOnSkillsInstall', true);
  let aiBackendsEntry = existingReceipt?.aiBackends;
  let aiBackendsSummary = '';

  if (installAiBackends) {
    try {
      const aiBackendsResult = await installManagedAiBackends(context, existingReceipt?.aiBackends);
      aiBackendsEntry = aiBackendsResult.entry;
      aiBackendsSummary = ` ai_backends: ${aiBackendsResult.summary}.`;
      outputChannel.appendLine(`[python] ${aiBackendsResult.summary}`);
    }
    catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      aiBackendsSummary = ` ai_backends: failed (${message}).`;
      outputChannel.appendLine(`[warn] ai_backends install failed: ${message}`);
      if (aiBackendsEntry) {
        aiBackendsEntry = {
          ...aiBackendsEntry,
          installStatus: 'failed',
          error: message
        };
      }
    }
  }

  const receipt: InstallReceipt = {
    extensionVersion: String(context.extension.packageJSON.version ?? '0.0.0'),
    installedAt: new Date().toISOString(),
    sourceKind: skillSource.kind,
    targetDir,
    skills: installedSkills,
    aiBackends: aiBackendsEntry
  };

  await saveReceipt(context, receipt);

  if (!options.skipConfiguredMcpInstall) {
    const autoInstallMcp = vscode.workspace.getConfiguration('jumpshell').get<boolean>('installMcpOnSkillsInstall', false);
    if (autoInstallMcp) {
      try {
        await installMcpConfig(context, { silent: true });
      }
      catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        outputChannel.appendLine(`[warn] MCP config install skipped: ${message}`);
      }
    }
  }

  const summary = `${mode === 'install' ? 'Installed' : 'Updated'} JumpShell skills in ${targetDir}. Installed ${installedCount}, updated ${updatedCount}, skipped ${skippedCount}, removed stale ${removedStaleCount}.${aiBackendsSummary}`;
  if (options.silent) {
    outputChannel.appendLine(`[skills] ${summary}`);
    return;
  }

  const action = await vscode.window.showInformationMessage(summary, 'Open folder');
  if (action === 'Open folder') {
    await revealInFileExplorer(targetDir);
  }
}

type InstallMcpOptions = {
  silent?: boolean;
  allowPathPrompt?: boolean;
};

async function installMcpConfig(context: vscode.ExtensionContext, options: InstallMcpOptions = {}) {
  const moduleSourceRoot = await resolveModuleSourceRoot(context, {
    allowPrompt: options.allowPathPrompt ?? true
  });
  const serverScriptPath = path.join(moduleSourceRoot, 'mcp', 'server.ps1');
  if (!await pathExists(serverScriptPath)) {
    throw new Error(`JumpShell MCP server script was not found at ${serverScriptPath}.`);
  }

  const template = await loadMcpTemplate(context);
  const renderedTemplate = applyTemplatePlaceholders(template, {
    moduleRoot: moduleSourceRoot,
    serverScript: serverScriptPath
  });

  if (!isRecord(renderedTemplate) || !isRecord(renderedTemplate.servers)) {
    throw new Error('JumpShell MCP template is invalid. Expected a top-level servers object.');
  }

  const targetPath = await resolveMcpConfigPath();
  await fs.mkdir(path.dirname(targetPath), { recursive: true });

  const config = await loadMcpConfig(targetPath);
  const existingServers = isRecord(config.servers) ? config.servers : {};
  config.servers = {
    ...existingServers,
    ...renderedTemplate.servers
  };

  await fs.writeFile(targetPath, JSON.stringify(config, null, 2) + '\n', 'utf8');
  outputChannel.appendLine(`[mcp] configured ${targetPath}`);

  if (!options.silent) {
    const action = await vscode.window.showInformationMessage(`JumpShell MCP configuration updated at ${targetPath}.`, 'Open file');
    if (action === 'Open file') {
      await revealInFileExplorer(targetPath);
    }
  }
}

async function loadMcpConfig(configPath: string): Promise<Record<string, unknown>> {
  if (!await pathExists(configPath)) {
    return {};
  }

  const raw = await fs.readFile(configPath, 'utf8');
  if (!raw.trim()) {
    return {};
  }

  const parsed = JSON.parse(raw) as unknown;
  if (!isRecord(parsed)) {
    throw new Error(`MCP config at ${configPath} is not a JSON object.`);
  }

  return parsed;
}

async function resolveMcpConfigPath(): Promise<string> {
  const scope = vscode.workspace.getConfiguration('jumpshell').get<string>('mcpConfigScope', 'user').toLowerCase();
  if (scope === 'workspace') {
    const workspaceFolder = vscode.workspace.workspaceFolders?.[0];
    if (!workspaceFolder) {
      throw new Error('No workspace is open. Open a workspace or switch jumpshell.mcpConfigScope to user.');
    }

    const workspaceMcpDirectory = await resolveWorkspaceMcpDirectory(workspaceFolder.uri.fsPath);
    return path.join(workspaceFolder.uri.fsPath, workspaceMcpDirectory, 'mcp.json');
  }

  return resolveUserMcpPath();
}

async function resolveUserMcpPath(): Promise<string> {
  const baseCandidates = [] as string[];
  const preferredEditorBasePaths = resolvePreferredEditorBasePaths();

  if (process.env.VSCODE_APPDATA) {
    baseCandidates.push(process.env.VSCODE_APPDATA);
  }

  if (process.env.VSCODE_PORTABLE) {
    baseCandidates.push(path.join(process.env.VSCODE_PORTABLE, 'user-data'));
  }

  baseCandidates.push(...preferredEditorBasePaths);

  for (const basePath of uniqueStrings(baseCandidates)) {
    if (!await pathExists(basePath)) {
      continue;
    }

    const userPath = path.join(basePath, 'User');
    if (!await pathExists(userPath)) {
      continue;
    }

    const profilePath = await getActiveProfilePath(basePath);
    if (profilePath) {
      return path.join(profilePath, 'mcp.json');
    }

    return path.join(userPath, 'mcp.json');
  }

  const fallbackBasePath = preferredEditorBasePaths[0];
  if (fallbackBasePath) {
    return path.join(fallbackBasePath, 'User', 'mcp.json');
  }

  return path.join(os.homedir(), '.config', 'Code', 'User', 'mcp.json');
}

async function getActiveProfilePath(basePath: string): Promise<string | undefined> {
  const storagePath = path.join(basePath, 'User', 'globalStorage', 'storage.json');
  if (!await pathExists(storagePath)) {
    return undefined;
  }

  try {
    const raw = await fs.readFile(storagePath, 'utf8');
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    const profileId = parsed['userDataProfiles.profile'];
    if (typeof profileId !== 'string' || !profileId.trim()) {
      return undefined;
    }

    const profilePath = path.join(basePath, 'User', 'profiles', profileId);
    if (await pathExists(profilePath)) {
      return profilePath;
    }
  }
  catch {
    return undefined;
  }

  return undefined;
}

async function resolveWorkspaceMcpDirectory(workspaceRoot: string): Promise<string> {
  const configured = vscode.workspace.getConfiguration('jumpshell').get<string>('workspaceMcpDirectory', 'auto').toLowerCase();
  if (configured === 'vscode') {
    return '.vscode';
  }

  if (configured === 'cursor') {
    return '.cursor';
  }

  const cursorMcpPath = path.join(workspaceRoot, '.cursor', 'mcp.json');
  const vscodeMcpPath = path.join(workspaceRoot, '.vscode', 'mcp.json');
  const [cursorMcpExists, vscodeMcpExists] = await Promise.all([
    pathExists(cursorMcpPath),
    pathExists(vscodeMcpPath)
  ]);

  if (cursorMcpExists && !vscodeMcpExists) {
    return '.cursor';
  }

  if (vscodeMcpExists && !cursorMcpExists) {
    return '.vscode';
  }

  return detectEditorVariant() === 'cursor' ? '.cursor' : '.vscode';
}

function detectEditorVariant(): EditorVariant {
  const hints = [
    process.env.VSCODE_GIT_ASKPASS_MAIN,
    process.env.VSCODE_IPC_HOOK,
    process.env.VSCODE_CWD,
    process.env.TERM_PROGRAM,
    process.env.TERM_PROGRAM_VERSION,
    process.execPath,
    process.argv0
  ]
    .filter((value): value is string => Boolean(value && value.trim()))
    .join('\n')
    .toLowerCase();

  if (hints.includes('cursor')) {
    return 'cursor';
  }

  if (hints.includes('code - insiders') || hints.includes('code-insiders') || hints.includes('insiders')) {
    return 'code-insiders';
  }

  if (hints.includes('vscodium') || hints.includes('codium')) {
    return 'vscodium';
  }

  if (hints.includes('visual studio code') || hints.includes('vscode') || hints.includes('code.exe')) {
    return 'code';
  }

  return 'unknown';
}

function resolvePreferredEditorBasePaths(): string[] {
  const preferredEditors = getPreferredEditorInstallNames(detectEditorVariant());
  return preferredEditors
    .map((editor) => resolveEditorBasePath(editor))
    .filter((candidate): candidate is string => Boolean(candidate));
}

function getPreferredEditorInstallNames(variant: EditorVariant): EditorInstallName[] {
  switch (variant) {
    case 'cursor':
      return ['Cursor', 'Code', 'Code - Insiders', 'VSCodium'];
    case 'code-insiders':
      return ['Code - Insiders', 'Code', 'Cursor', 'VSCodium'];
    case 'vscodium':
      return ['VSCodium', 'Code', 'Code - Insiders', 'Cursor'];
    default:
      return ['Code', 'Code - Insiders', 'Cursor', 'VSCodium'];
  }
}

function resolveEditorBasePath(editor: EditorInstallName): string | undefined {
  if (process.platform === 'win32') {
    const appData = process.env.APPDATA;
    if (!appData) {
      return undefined;
    }

    switch (editor) {
      case 'Code':
      case 'Code - Insiders':
      case 'Cursor':
      case 'VSCodium':
        return path.join(appData, editor);
    }
  }

  if (process.platform === 'darwin') {
    return path.join(os.homedir(), 'Library', 'Application Support', editor);
  }

  return path.join(os.homedir(), '.config', editor);
}

type ResolveModuleSourceRootOptions = {
  allowPrompt?: boolean;
};

async function resolveModuleSourceRoot(context: vscode.ExtensionContext, options: ResolveModuleSourceRootOptions = {}): Promise<string> {
  const configuredPath = vscode.workspace.getConfiguration('jumpshell').get<string>('moduleRootPath', '').trim();
  const candidateBases = [] as string[];

  if (configuredPath) {
    candidateBases.push(expandHome(configuredPath));
  }

  candidateBases.push(path.resolve(context.extensionPath, '..', '..'));

  const discoveredModuleRoot = await detectModuleRootFromPowerShell();
  if (discoveredModuleRoot) {
    candidateBases.push(discoveredModuleRoot);
  }

  for (const candidateBase of uniqueStrings(candidateBases)) {
    const resolved = await resolveSourceRootCandidate(candidateBase);
    if (resolved) {
      return resolved;
    }
  }

  if (!options.allowPrompt) {
    throw new Error('JumpShell module root could not be auto-detected. Set jumpshell.moduleRootPath or run JumpShell: Install MCP Configuration manually.');
  }

  const picked = await vscode.window.showOpenDialog({
    canSelectMany: false,
    canSelectFiles: false,
    canSelectFolders: true,
    openLabel: 'Select JumpShell Module Folder'
  });

  const pickedPath = picked?.[0]?.fsPath;
  if (!pickedPath) {
    throw new Error('JumpShell module root was not selected.');
  }

  const resolvedPicked = await resolveSourceRootCandidate(pickedPath);
  if (!resolvedPicked) {
    throw new Error(`The selected folder does not contain a valid JumpShell module: ${pickedPath}`);
  }

  return resolvedPicked;
}

async function resolveSourceRootCandidate(basePath: string): Promise<string | undefined> {
  const sourceCandidate = path.join(basePath, 'src', 'pwsh');
  const sourceManifest = path.join(sourceCandidate, 'JumpShellPs.psd1');
  const sourceServer = path.join(sourceCandidate, 'mcp', 'server.ps1');
  if (await pathExists(sourceManifest) && await pathExists(sourceServer)) {
    return sourceCandidate;
  }

  const normalizedBase = path.normalize(basePath);
  const baseName = path.basename(normalizedBase).toLowerCase();
  const parentName = path.basename(path.dirname(normalizedBase)).toLowerCase();
  const isSourceRootPath = baseName === 'pwsh' && parentName === 'src';

  if (isSourceRootPath) {
    const directManifest = path.join(basePath, 'JumpShellPs.psd1');
    const directServer = path.join(basePath, 'mcp', 'server.ps1');
    if (await pathExists(directManifest) && await pathExists(directServer)) {
      return basePath;
    }
  }

  return undefined;
}

async function detectModuleRootFromPowerShell(): Promise<string | undefined> {
  const command = '$m = Get-Module -ListAvailable -Name JumpShellPs | Sort-Object Version -Descending | Select-Object -First 1; if ($m) { [Console]::Out.WriteLine($m.ModuleBase) }';
  const binaries = process.platform === 'win32' ? ['pwsh.exe', 'pwsh'] : ['pwsh'];

  for (const binary of binaries) {
    try {
      const result = await execFileAsync(binary, ['-NoLogo', '-NoProfile', '-Command', command], {
        timeout: 8000,
        windowsHide: true,
        maxBuffer: 1024 * 1024
      });

      const moduleRoot = result.stdout.trim();
      if (moduleRoot) {
        return moduleRoot;
      }
    }
    catch {
      continue;
    }
  }

  return undefined;
}

async function loadMcpTemplate(context: vscode.ExtensionContext): Promise<Record<string, unknown>> {
  const candidates = [
    path.join(context.extensionPath, 'assets', 'mcps', mcpTemplateFileName),
    path.resolve(context.extensionPath, '..', '..', 'mcps', mcpTemplateFileName)
  ];

  for (const candidate of candidates) {
    if (!await pathExists(candidate)) {
      continue;
    }

    const raw = await fs.readFile(candidate, 'utf8');
    const parsed = JSON.parse(raw) as unknown;
    if (!isRecord(parsed)) {
      throw new Error(`MCP template at ${candidate} is not a JSON object.`);
    }

    return parsed;
  }

  return {
    servers: {
      jumpshellPs: {
        type: 'stdio',
        command: 'pwsh',
        args: [
          '-NoLogo',
          '-NoProfile',
          '-ExecutionPolicy',
          'Bypass',
          '-File',
          '${serverScript}',
          '-ModuleRoot',
          '${moduleRoot}'
        ],
        env: {
          JUMPSHELL_MCP_DISABLE_AUTOSTART: '1',
          TERM_PROGRAM: 'mcp'
        }
      }
    }
  };
}

function applyTemplatePlaceholders(value: unknown, replacements: Record<string, string>): unknown {
  if (typeof value === 'string') {
    return value.replace(/\$\{([a-zA-Z0-9_]+)\}/g, (match, key: string) => {
      const replacement = replacements[key];
      return typeof replacement === 'string' ? replacement : match;
    });
  }

  if (Array.isArray(value)) {
    return value.map((entry) => applyTemplatePlaceholders(entry, replacements));
  }

  if (isRecord(value)) {
    const output = {} as Record<string, unknown>;
    for (const [entryKey, entryValue] of Object.entries(value)) {
      output[entryKey] = applyTemplatePlaceholders(entryValue, replacements);
    }

    return output;
  }

  return value;
}

function expandHome(inputPath: string): string {
  if (inputPath === '~') {
    return os.homedir();
  }

  if (inputPath.startsWith('~/') || inputPath.startsWith('~\\')) {
    return path.join(os.homedir(), inputPath.slice(2));
  }

  return inputPath;
}

function uniqueStrings(values: string[]): string[] {
  return Array.from(new Set(values.map((value) => value.trim()).filter((value) => value.length > 0)));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

async function revealInFileExplorer(targetPath: string) {
  await vscode.commands.executeCommand('revealFileInOS', vscode.Uri.file(targetPath));
}

async function resolveSkillSource(context: vscode.ExtensionContext): Promise<SkillSource> {
  const assetsRoot = path.join(context.extensionPath, 'assets', 'skills');
  const assetsManifest = path.join(context.extensionPath, 'assets', 'skills-manifest.json');
  if (await pathExists(assetsRoot)) {
    return {
      kind: 'assets',
      rootPath: assetsRoot,
      manifestPath: assetsManifest
    };
  }

  const repoSkillsRoot = path.resolve(context.extensionPath, '..', '..', 'skills');
  if (await pathExists(repoSkillsRoot)) {
    return {
      kind: 'repo',
      rootPath: repoSkillsRoot
    };
  }

  throw new Error('No bundled skill assets or repository skills folder could be found. Run the build first or open the JumpshellPs repo.');
}

async function loadManifest(skillSource: SkillSource): Promise<SkillManifestEntry[]> {
  if (skillSource.manifestPath && await pathExists(skillSource.manifestPath)) {
    const raw = await fs.readFile(skillSource.manifestPath, 'utf8');
    const parsed = JSON.parse(raw) as { skills?: SkillManifestEntry[] };
    if (Array.isArray(parsed.skills)) {
      return parsed.skills;
    }
  }

  return buildManifest(skillSource.rootPath);
}

async function buildManifest(rootPath: string): Promise<SkillManifestEntry[]> {
  const entries = await fs.readdir(rootPath, { withFileTypes: true });
  const skills = [] as SkillManifestEntry[];

  for (const entry of entries.filter((candidate) => candidate.isDirectory()).sort((left, right) => left.name.localeCompare(right.name))) {
    if (shouldIgnoreName(entry.name)) {
      continue;
    }

    const skillRoot = path.join(rootPath, entry.name);
    const files = await collectFiles(skillRoot, skillRoot);
    skills.push({
      name: entry.name,
      relativePath: entry.name,
      hash: await hashFiles(skillRoot, files),
      fileCount: files.length
    });
  }

  return skills;
}

function resolveTargetSkillsDir(): string {
  const configuredPath = vscode.workspace.getConfiguration('jumpshell').get<string>('skillsPath', '~/.agents/skills').trim();
  if (!configuredPath || configuredPath === '~') {
    return path.join(os.homedir(), '.agents', 'skills');
  }

  if (configuredPath.startsWith('~/') || configuredPath.startsWith('~\\')) {
    return path.join(os.homedir(), configuredPath.slice(2));
  }

  if (path.isAbsolute(configuredPath)) {
    return configuredPath;
  }

  return path.resolve(os.homedir(), configuredPath);
}

async function resolveAiBackendsSource(context: vscode.ExtensionContext): Promise<AiBackendsSource> {
  // Prefer repo source (editable install) for dev; fall back to bundled assets (regular install).
  const repoRoot = path.resolve(context.extensionPath, '..', '..', 'src', 'python', 'ai-backends');
  const repoPyproject = path.join(repoRoot, 'pyproject.toml');
  if (await pathExists(repoPyproject)) {
    return {
      kind: 'repo',
      rootPath: repoRoot,
      editable: true
    };
  }

  const assetsRoot = path.join(context.extensionPath, 'assets', 'src', 'python', 'ai-backends');
  const assetsPyproject = path.join(assetsRoot, 'pyproject.toml');
  if (await pathExists(assetsPyproject)) {
    return {
      kind: 'assets',
      rootPath: assetsRoot,
      editable: false
    };
  }

  throw new Error('No bundled ai-backends source or repository src/python/ai-backends folder could be found.');
}

async function installManagedAiBackends(
  context: vscode.ExtensionContext,
  existingInstall: InstalledAiBackends | undefined
): Promise<ManagedAiBackendsResult> {
  const source = await resolveAiBackendsSource(context);
  const sourceFiles = await collectFiles(source.rootPath, source.rootPath);
  if (sourceFiles.length === 0) {
    throw new Error(`ai_backends source is empty at ${source.rootPath}`);
  }

  const sourceHash = await hashFiles(source.rootPath, sourceFiles);

  // Clean up legacy copy-based installs (targetDir was used in older versions).
  if (existingInstall?.targetDir && await pathExists(existingInstall.targetDir)) {
    await fs.rm(existingInstall.targetDir, { recursive: true, force: true });
    outputChannel.appendLine(`[python] Removed legacy ai_backends copy: ${existingInstall.targetDir}`);
  }

  const alreadyCurrent = Boolean(
    existingInstall &&
    existingInstall.hash === sourceHash &&
    existingInstall.installStatus === 'ok' &&
    existingInstall.installMode === (source.editable ? 'editable' : 'regular')
  );

  if (alreadyCurrent) {
    return {
      entry: existingInstall!,
      summary: `ai_backends already current (${source.kind}, ${source.editable ? 'editable' : 'regular'})`
    };
  }

  const pipResult = await pipInstallAiBackends(source.rootPath, source.editable);
  const installMode = source.editable ? 'editable' : 'regular' as const;

  const entry: InstalledAiBackends = {
    hash: sourceHash,
    installMode,
    installStatus: pipResult.ok ? 'ok' : 'failed',
    pipCommand: pipResult.command,
    error: pipResult.ok ? undefined : pipResult.error
  };

  const summary = pipResult.ok
    ? `pip ${installMode} install ok (${source.kind})${pipResult.command ? ` via ${pipResult.command}` : ''}`
    : `pip ${installMode} install failed (${pipResult.error ?? 'unknown error'})`;

  return { entry, summary };
}

async function pipInstallAiBackends(sourcePath: string, editable: boolean): Promise<{ ok: boolean; command?: string; error?: string }> {
  const attempts = getPipInstallAttempts(sourcePath, editable);
  let lastError = 'No Python interpreter with pip was found.';

  for (const attempt of attempts) {
    try {
      outputChannel.appendLine(`[python] Running: ${attempt.display}`);
      const result = await execFileAsync(attempt.binary, attempt.args, {
        timeout: 180000,
        windowsHide: true,
        maxBuffer: 8 * 1024 * 1024
      });

      const stderr = toProcessText(result.stderr).trim();
      if (stderr) {
        outputChannel.appendLine(`[python] ${stderr}`);
      }

      return {
        ok: true,
        command: attempt.display
      };
    }
    catch (error) {
      lastError = formatExecError(error);
      outputChannel.appendLine(`[python] Command failed: ${attempt.display}`);
      outputChannel.appendLine(`[python] ${lastError}`);
    }
  }

  return {
    ok: false,
    error: lastError
  };
}

function getPipInstallAttempts(sourcePath: string, editable: boolean): Array<{ binary: string; args: string[]; display: string }> {
  const quotedPath = `"${sourcePath}"`;
  const flag = editable ? '-e' : '';
  const flagDisplay = editable ? '-e ' : '';
  const installArgs = editable
    ? ['-m', 'pip', 'install', '-e', sourcePath]
    : ['-m', 'pip', 'install', sourcePath];

  if (process.platform === 'win32') {
    return [
      {
        binary: 'py',
        args: ['-3', ...installArgs],
        display: `py -3 -m pip install ${flagDisplay}${quotedPath}`
      },
      {
        binary: 'py',
        args: installArgs,
        display: `py -m pip install ${flagDisplay}${quotedPath}`
      },
      {
        binary: 'python',
        args: installArgs,
        display: `python -m pip install ${flagDisplay}${quotedPath}`
      },
      {
        binary: 'python3',
        args: installArgs,
        display: `python3 -m pip install ${flagDisplay}${quotedPath}`
      }
    ];
  }

  return [
    {
      binary: 'python3',
      args: installArgs,
      display: `python3 -m pip install ${flagDisplay}${quotedPath}`
    },
    {
      binary: 'python',
      args: installArgs,
      display: `python -m pip install ${flagDisplay}${quotedPath}`
    }
  ];
}

function formatExecError(error: unknown): string {
  if (!(error instanceof Error)) {
    return String(error);
  }

  const candidate = error as Error & { stderr?: string | Buffer; stdout?: string | Buffer };
  const stderr = toProcessText(candidate.stderr).trim();
  if (stderr) {
    return stderr;
  }

  const stdout = toProcessText(candidate.stdout).trim();
  if (stdout) {
    return stdout;
  }

  return error.message;
}

function toProcessText(value: unknown): string {
  if (typeof value === 'string') {
    return value;
  }

  if (value instanceof Buffer) {
    return value.toString('utf8');
  }

  return '';
}

async function collectFiles(directoryPath: string, baseDir: string): Promise<string[]> {
  const files = [] as string[];
  const entries = await fs.readdir(directoryPath, { withFileTypes: true });

  for (const entry of entries) {
    if (shouldIgnoreName(entry.name)) {
      continue;
    }

    const fullPath = path.join(directoryPath, entry.name);
    if (entry.isDirectory()) {
      files.push(...await collectFiles(fullPath, baseDir));
      continue;
    }

    if (!entry.isFile()) {
      continue;
    }

    files.push(path.relative(baseDir, fullPath).split(path.sep).join('/'));
  }

  return files.sort((left, right) => left.localeCompare(right));
}

async function hashFiles(baseDir: string, files: string[]): Promise<string> {
  const hash = createHash('sha256');
  for (const relativeFile of files) {
    const bytes = await fs.readFile(path.join(baseDir, relativeFile));
    hash.update(relativeFile);
    hash.update('\0');
    hash.update(bytes);
    hash.update('\0');
  }

  return hash.digest('hex');
}

async function copyDirectory(sourceDir: string, targetDir: string): Promise<void> {
  await fs.mkdir(targetDir, { recursive: true });
  const entries = await fs.readdir(sourceDir, { withFileTypes: true });
  for (const entry of entries) {
    if (shouldIgnoreName(entry.name)) {
      continue;
    }

    const sourcePath = path.join(sourceDir, entry.name);
    const targetPath = path.join(targetDir, entry.name);
    if (entry.isDirectory()) {
      await copyDirectory(sourcePath, targetPath);
      continue;
    }

    if (!entry.isFile()) {
      continue;
    }

    await fs.mkdir(path.dirname(targetPath), { recursive: true });
    await fs.copyFile(sourcePath, targetPath);
  }
}

function shouldIgnoreName(name: string): boolean {
  return ignoredNames.has(name) || ignoredExtensions.has(path.extname(name).toLowerCase());
}

async function loadReceipt(context: vscode.ExtensionContext): Promise<InstallReceipt | undefined> {
  const receiptPath = getReceiptPath(context);
  if (!await pathExists(receiptPath)) {
    return undefined;
  }

  try {
    const raw = await fs.readFile(receiptPath, 'utf8');
    return JSON.parse(raw) as InstallReceipt;
  }
  catch (error) {
    outputChannel.appendLine(`[warn] Failed to read install receipt: ${error instanceof Error ? error.message : String(error)}`);
    return undefined;
  }
}

async function saveReceipt(context: vscode.ExtensionContext, receipt: InstallReceipt): Promise<void> {
  await fs.mkdir(context.globalStorageUri.fsPath, { recursive: true });
  await fs.writeFile(getReceiptPath(context), JSON.stringify(receipt, null, 2) + '\n', 'utf8');
}

function getReceiptPath(context: vscode.ExtensionContext): string {
  return path.join(context.globalStorageUri.fsPath, receiptFileName);
}

async function pathExists(targetPath: string): Promise<boolean> {
  try {
    await fs.access(targetPath);
    return true;
  }
  catch {
    return false;
  }
}