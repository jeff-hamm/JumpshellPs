import * as path from 'node:path';
import * as os from 'node:os';
import { promises as fsPromises } from 'node:fs';
import * as vscode from 'vscode';
import { getOutputChannel } from './output';
import { pathExists } from './utils';
import { ensurePython, commandExists } from './prereqs';

type InstallAiBackendsOptions = {
  silent?: boolean;
};

async function resolveAiBackendsPath(context: vscode.ExtensionContext): Promise<string | undefined> {
  const bundled = path.join(context.extensionPath, 'assets', 'src', 'python', 'ai-backends');
  if (await pathExists(bundled)) {
    return bundled;
  }
  // Dev mode fallback: use the workspace source tree directly
  const dev = path.resolve(context.extensionPath, '..', '..', 'src', 'python', 'ai-backends');
  if (await pathExists(dev)) {
    return dev;
  }
  return undefined;
}

export async function installAiBackends(
  context: vscode.ExtensionContext,
  options: InstallAiBackendsOptions = {}
): Promise<void> {
  const outputChannel = getOutputChannel();
  const sourcePath = await resolveAiBackendsPath(context);

  if (!sourcePath) {
    const msg = 'ai-backends bundled package not found — reinstall the JumpShell extension.';
    outputChannel.appendLine(`[ai-backends] ${msg}`);
    if (!options.silent) {
      void vscode.window.showErrorMessage(`JumpShell: ${msg}`);
    }
    return;
  }

  outputChannel.appendLine(`[ai-backends] Installing from ${sourcePath}`);

  // Ensure Python 3 is available before running pip.
  const pythonAvailable = await ensurePython();
  if (!pythonAvailable) {
    outputChannel.appendLine('[ai-backends] Python not available — skipping ai-backends install');
    return;
  }

  const isWindows = process.platform === 'win32';
  const terminal = vscode.window.createTerminal({
    name: 'JumpShell — Install ai-backends',
    shellPath: isWindows ? 'pwsh.exe' : undefined,
    isTransient: false,
  });
  terminal.show();

  if (isWindows) {
    terminal.sendText(
      `pip install --user "${sourcePath}"; ` +
        `if ($LASTEXITCODE -eq 0) { Write-Host 'ai-backends installed.' -ForegroundColor Green } ` +
        `else { pip3 install --user "${sourcePath}" }`
    );
  } else {
    terminal.sendText(`pip3 install --user "${sourcePath}" 2>/dev/null || pip install --user "${sourcePath}"`);
  }

  if (!options.silent) {
    void vscode.window.showInformationMessage(
      'JumpShell: Installing ai-backends — check the terminal for progress.'
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// configureAiCli — native VS Code backend configuration wizard
// ─────────────────────────────────────────────────────────────────────────────

interface ApiBackend {
  name: string;
  label: string;
  description: string;
  envKey: string;
  keyLabel: string;
  keyHint: string;
}

interface CliBackend {
  name: string;
  label: string;
  description: string;
  command: string;
  installHint: string;
}

const API_BACKENDS: readonly ApiBackend[] = [
  {
    name: 'gemini',
    label: '$(cloud) Gemini',
    description: 'Google Gemini API — free tier available',
    envKey: 'GEMINI_API_KEY',
    keyLabel: 'Gemini API Key',
    keyHint: 'Get a free key at https://aistudio.google.com/apikey',
  },
  {
    name: 'openai',
    label: '$(rocket) OpenAI',
    description: 'OpenAI API — GPT-4o, o1, etc.',
    envKey: 'OPENAI_API_KEY',
    keyLabel: 'OpenAI API Key',
    keyHint: 'https://platform.openai.com/api-keys',
  },
  {
    name: 'anthropic',
    label: '$(hubot) Anthropic',
    description: 'Anthropic API — Claude models',
    envKey: 'ANTHROPIC_API_KEY',
    keyLabel: 'Anthropic API Key',
    keyHint: 'https://console.anthropic.com/settings/keys',
  },
  {
    name: 'github-api',
    label: '$(github) GitHub Models',
    description: 'GitHub Models API — free with a GitHub account',
    envKey: 'GITHUB_TOKEN',
    keyLabel: 'GitHub Personal Access Token',
    keyHint: 'Create a PAT at https://github.com/settings/tokens',
  },
];

const CLI_BACKENDS: readonly CliBackend[] = [
  {
    name: 'copilot-cli',
    label: '$(copilot) GitHub Copilot CLI',
    description: 'GitHub Copilot terminal agent',
    command: 'copilot',
    installHint: 'npm install -g @anthropic-ai/copilot',
  },
  {
    name: 'cursor',
    label: '$(terminal) Cursor Agent',
    description: 'Cursor IDE agent CLI',
    command: 'agent',
    installHint: 'Install from https://cursor.com',
  },
];

const ENABLED_BACKENDS_KEY = 'enabled_backends';

function resolveConfigFilePath(): string {
  return path.join(os.homedir(), '.config', 'ai_backends', 'config.json');
}

type BackendItem = vscode.QuickPickItem & { backendIdx: number; isApi: boolean };

export async function configureAiCli(context: vscode.ExtensionContext): Promise<void> {
  const outputChannel = getOutputChannel();

  // ── 1. Probe current state ───────────────────────────────────────────────
  const existingKeys = new Map<string, string | undefined>();
  for (const b of API_BACKENDS) {
    existingKeys.set(b.envKey, await context.secrets.get(b.envKey));
  }

  const cliAvailable = new Map<string, boolean>();
  for (const b of CLI_BACKENDS) {
    cliAvailable.set(b.name, await commandExists(b.command));
  }

  // ── 2. Backend selection QuickPick ───────────────────────────────────────
  const items: BackendItem[] = [
    ...API_BACKENDS.map((b, i): BackendItem => {
      const hasKey = Boolean(existingKeys.get(b.envKey));
      return {
        backendIdx: i,
        isApi: true,
        label: b.label,
        description: b.description,
        detail: hasKey
          ? '$(check) Key already stored — select to update'
          : `$(warning) No key configured — ${b.keyHint}`,
        picked: !hasKey,
      };
    }),
    ...CLI_BACKENDS.map((b, i): BackendItem => {
      const available = cliAvailable.get(b.name) ?? false;
      return {
        backendIdx: i,
        isApi: false,
        label: b.label,
        description: b.description,
        detail: available
          ? '$(check) Found in PATH — will be enabled'
          : `$(circle-slash) Not installed — ${b.installHint}`,
        picked: available,
      };
    }),
  ];

  const selected = await vscode.window.showQuickPick(items, {
    canPickMany: true,
    title: 'Configure AI Backends',
    placeHolder: 'Select backends to configure — pre-checked items need attention',
  });

  if (!selected || selected.length === 0) {
    return;
  }

  // ── 3. Collect credentials ───────────────────────────────────────────────
  const collected: Record<string, string> = {};
  const enabledBackends: string[] = [];

  for (const item of selected) {
    if (item.isApi) {
      const backend = API_BACKENDS[item.backendIdx];
      const existingKey = existingKeys.get(backend.envKey);

      const value = await vscode.window.showInputBox({
        title: `Configure ${backend.name}`,
        prompt: `Enter your ${backend.keyLabel}`,
        placeHolder: existingKey ? 'Leave blank to keep the existing key' : backend.keyHint,
        password: true,
        ignoreFocusOut: true,
      });

      if (value === undefined) {
        // User pressed Escape — abort the whole wizard.
        return;
      }

      const resolved = value.trim() || existingKey;
      if (resolved) {
        collected[backend.envKey] = resolved;
        enabledBackends.push(backend.name);
      }
    } else {
      const backend = CLI_BACKENDS[item.backendIdx];
      if (cliAvailable.get(backend.name)) {
        enabledBackends.push(backend.name);
      } else {
        void vscode.window.showInformationMessage(
          `${backend.name} is not installed. ${backend.installHint}`
        );
      }
    }
  }

  if (Object.keys(collected).length === 0 && enabledBackends.length === 0) {
    void vscode.window.showInformationMessage('JumpShell: No changes made.');
    return;
  }

  // ── 4. Store in VS Code SecretStorage ────────────────────────────────────
  let storedCount = 0;
  for (const [key, value] of Object.entries(collected)) {
    await context.secrets.store(key, value);
    outputChannel.appendLine(`[configure] Stored secret: ${key}`);
    storedCount++;
  }

  // ── 5. Write config.json for the ai-backends Python CLI ─────────────────
  // Merges with any existing file so unrelated keys are preserved.
  const configPath = resolveConfigFilePath();
  let existingConfig: Record<string, unknown> = {};
  try {
    const raw = await fsPromises.readFile(configPath, 'utf8');
    existingConfig = JSON.parse(raw) as Record<string, unknown>;
  } catch {
    // File absent or invalid JSON — start fresh.
  }

  const configData: Record<string, unknown> = {
    ...existingConfig,
    ...collected,
    [ENABLED_BACKENDS_KEY]: enabledBackends,
  };

  try {
    await fsPromises.mkdir(path.dirname(configPath), { recursive: true });
    await fsPromises.writeFile(configPath, JSON.stringify(configData, null, 2) + '\n', 'utf8');
    outputChannel.appendLine(`[configure] Config written to ${configPath}`);
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    outputChannel.appendLine(`[configure] Failed to write config file: ${message}`);
    void vscode.window.showWarningMessage(
      `JumpShell: Could not write config to ${configPath}: ${message}`
    );
  }

  void vscode.window.showInformationMessage(
    `JumpShell: ${storedCount} credential(s) stored. ` +
      `Enabled backends: ${enabledBackends.join(', ') || 'none'}.`
  );
}
