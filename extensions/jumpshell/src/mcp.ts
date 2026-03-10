import { promises as fs } from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { getOutputChannel } from './output';
import { pathExists, isRecord, expandHome, uniqueStrings, execFileAsync } from './utils';

type InstallMcpOptions = {
  silent?: boolean;
};

const mcpTemplateFileName = 'jumpshellps.json';

export async function installMcpConfig(context: vscode.ExtensionContext, options: InstallMcpOptions = {}): Promise<void> {
  const outputChannel = getOutputChannel();
  const moduleSourceRoot = await resolveModuleSourceRoot(context);
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

    return path.join(workspaceFolder.uri.fsPath, '.vscode', 'mcp.json');
  }

  return resolveUserMcpPath();
}

async function resolveUserMcpPath(): Promise<string> {
  const appData = process.env.APPDATA;
  const baseCandidates = [] as string[];

  if (process.env.VSCODE_APPDATA) {
    baseCandidates.push(process.env.VSCODE_APPDATA);
  }

  if (process.env.VSCODE_PORTABLE) {
    baseCandidates.push(path.join(process.env.VSCODE_PORTABLE, 'user-data'));
  }

  if (appData) {
    baseCandidates.push(
      path.join(appData, 'Code - Insiders'),
      path.join(appData, 'Code'),
      path.join(appData, 'Cursor'),
      path.join(appData, 'VSCodium')
    );
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

  if (appData) {
    return path.join(appData, 'Code', 'User', 'mcp.json');
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
