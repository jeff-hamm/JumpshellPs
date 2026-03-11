import { promises as fs } from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { getOutputChannel } from './output';
import { pathExists, isRecord, expandHome, uniqueStrings, execFileAsync } from './utils';

type InstallMcpOptions = {
  silent?: boolean;
};

const mcpTemplateFileName = 'jumpshell.json';

export async function installMcpConfig(context: vscode.ExtensionContext, options: InstallMcpOptions = {}): Promise<void> {
  const outputChannel = getOutputChannel();
  const moduleSourceRoot = await resolveModuleSourceRoot(context);
  const serverScriptPath = path.join(moduleSourceRoot, 'mcp', 'server.ps1');
  if (!await pathExists(serverScriptPath)) {
    throw new Error(`Jumpshell MCP server script was not found at ${serverScriptPath}.`);
  }

  const template = await loadMcpTemplate(context);
  const renderedTemplate = applyTemplatePlaceholders(template, {
    moduleRoot: moduleSourceRoot,
    serverScript: serverScriptPath
  });

  if (!isRecord(renderedTemplate) || !isRecord(renderedTemplate.servers)) {
    throw new Error('Jumpshell MCP template is invalid. Expected a top-level servers object.');
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
    const action = await vscode.window.showInformationMessage(`Jumpshell MCP configuration updated at ${targetPath}.`, 'Open file');
    if (action === 'Open file') {
      const { revealInFileExplorer } = await import('./utils');
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

    const workspaceConfigDir = await resolveWorkspaceMcpDirectory(workspaceFolder.uri.fsPath);
    return path.join(workspaceFolder.uri.fsPath, workspaceConfigDir, 'mcp.json');
  }

  return resolveUserMcpPath();
}

async function resolveUserMcpPath(): Promise<string> {
  const baseCandidates = [] as string[];
  const configDirs = resolveEditorConfigDirectories();

  if (process.env.VSCODE_APPDATA) {
    baseCandidates.push(process.env.VSCODE_APPDATA);
  }

  if (process.env.VSCODE_PORTABLE) {
    baseCandidates.push(path.join(process.env.VSCODE_PORTABLE, 'user-data'));
  }

  if (process.platform === 'win32') {
    const appData = process.env.APPDATA ?? path.join(os.homedir(), 'AppData', 'Roaming');
    for (const configDir of configDirs) {
      baseCandidates.push(path.join(appData, configDir));
    }
  } else if (process.platform === 'darwin') {
    const appSupportRoot = path.join(os.homedir(), 'Library', 'Application Support');
    for (const configDir of configDirs) {
      baseCandidates.push(path.join(appSupportRoot, configDir));
    }
  } else {
    const configRoot = process.env.XDG_CONFIG_HOME ?? path.join(os.homedir(), '.config');
    for (const configDir of configDirs) {
      baseCandidates.push(path.join(configRoot, configDir));
    }
  }

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

  const fallbackConfigDir = resolvePreferredEditorConfigDirectory();
  if (process.platform === 'win32') {
    const appData = process.env.APPDATA ?? path.join(os.homedir(), 'AppData', 'Roaming');
    return path.join(appData, fallbackConfigDir, 'User', 'mcp.json');
  }

  if (process.platform === 'darwin') {
    return path.join(os.homedir(), 'Library', 'Application Support', fallbackConfigDir, 'User', 'mcp.json');
  }

  const configRoot = process.env.XDG_CONFIG_HOME ?? path.join(os.homedir(), '.config');
  return path.join(configRoot, fallbackConfigDir, 'User', 'mcp.json');
}

async function resolveWorkspaceMcpDirectory(workspaceRootPath: string): Promise<string> {
  const preference = vscode.workspace.getConfiguration('jumpshell').get<string>('workspaceMcpDirectory', 'auto').toLowerCase();
  if (preference === 'vscode') {
    return '.vscode';
  }

  if (preference === 'cursor') {
    return '.cursor';
  }

  const preferred = resolveEditorKind() === 'cursor' ? '.cursor' : '.vscode';
  const alternate = preferred === '.cursor' ? '.vscode' : '.cursor';
  const preferredPath = path.join(workspaceRootPath, preferred, 'mcp.json');
  const alternatePath = path.join(workspaceRootPath, alternate, 'mcp.json');

  if (await pathExists(preferredPath)) {
    return preferred;
  }

  if (await pathExists(alternatePath)) {
    return alternate;
  }

  return preferred;
}

type EditorKind = 'code' | 'insiders' | 'cursor' | 'codium';

function resolveEditorKind(): EditorKind {
  const appName = vscode.env.appName.toLowerCase();
  if (appName.includes('cursor')) {
    return 'cursor';
  }

  if (appName.includes('codium')) {
    return 'codium';
  }

  if (appName.includes('insiders')) {
    return 'insiders';
  }

  return 'code';
}

function resolvePreferredEditorConfigDirectory(): string {
  switch (resolveEditorKind()) {
    case 'cursor':
      return 'Cursor';
    case 'insiders':
      return 'Code - Insiders';
    case 'codium':
      return 'VSCodium';
    default:
      return 'Code';
  }
}

function resolveEditorConfigDirectories(): string[] {
  const preferredDir = resolvePreferredEditorConfigDirectory();
  return uniqueStrings([
    preferredDir,
    'Cursor',
    'Code - Insiders',
    'Code',
    'VSCodium'
  ]);
}

export async function checkMcpConfigured(): Promise<boolean> {
  try {
    const targetPath = await resolveMcpConfigPath();
    const config = await loadMcpConfig(targetPath);
    return isRecord(config.servers) && 'jumpshell' in config.servers;
  }
  catch {
    return false;
  }
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

async function resolveModuleSourceRoot(context: vscode.ExtensionContext): Promise<string> {
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

  const picked = await vscode.window.showOpenDialog({
    canSelectMany: false,
    canSelectFiles: false,
    canSelectFolders: true,
    openLabel: 'Select Jumpshell Module Folder'
  });

  const pickedPath = picked?.[0]?.fsPath;
  if (!pickedPath) {
    throw new Error('Jumpshell module root was not selected.');
  }

  const resolvedPicked = await resolveSourceRootCandidate(pickedPath);
  if (!resolvedPicked) {
    throw new Error(`The selected folder does not contain a valid Jumpshell module: ${pickedPath}`);
  }

  return resolvedPicked;
}

async function resolveSourceRootCandidate(basePath: string): Promise<string | undefined> {
  const sourceCandidate = path.join(basePath, 'src', 'pwsh');
  const sourceManifest = path.join(sourceCandidate, 'Jumpshell.psd1');
  const sourceServer = path.join(sourceCandidate, 'mcp', 'server.ps1');
  if (await pathExists(sourceManifest) && await pathExists(sourceServer)) {
    return sourceCandidate;
  }

  const normalizedBase = path.normalize(basePath);
  const baseName = path.basename(normalizedBase).toLowerCase();
  const parentName = path.basename(path.dirname(normalizedBase)).toLowerCase();
  const isSourceRootPath = baseName === 'pwsh' && parentName === 'src';

  if (isSourceRootPath) {
    const directManifest = path.join(basePath, 'Jumpshell.psd1');
    const directServer = path.join(basePath, 'mcp', 'server.ps1');
    if (await pathExists(directManifest) && await pathExists(directServer)) {
      return basePath;
    }
  }

  return undefined;
}

async function detectModuleRootFromPowerShell(): Promise<string | undefined> {
  const command = '$m = Get-Module -ListAvailable -Name Jumpshell | Sort-Object Version -Descending | Select-Object -First 1; if ($m) { [Console]::Out.WriteLine($m.ModuleBase) }';
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
      jumpshell: {
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
