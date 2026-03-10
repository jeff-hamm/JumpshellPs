import * as vscode from 'vscode';
import { promises as fs } from 'node:fs';
import { watch, type FSWatcher } from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import { getOutputChannel } from './output';
import { execFileAsync } from './utils';

async function resolveAiCli(): Promise<string | undefined> {
  const candidates = process.platform === 'win32'
    ? ['ai-cli', 'ai-cli.exe', 'ai-backends', 'ai-backends.exe']
    : ['ai-cli', 'ai-backends'];

  for (const candidate of candidates) {
    try {
      await execFileAsync(candidate, ['--help'], { timeout: 5000, windowsHide: true });
      return candidate;
    }
    catch {
      continue;
    }
  }

  return undefined;
}

export async function configureJumpshell(context: vscode.ExtensionContext): Promise<void> {
  const outputChannel = getOutputChannel();

  const cliCommand = await resolveAiCli();
  if (!cliCommand) {
    void vscode.window.showErrorMessage(
      'JumpShell: ai-cli is not installed. Install ai-backends first (pip install ai-backends).'
    );
    return;
  }

  const tmpDir = await fs.mkdtemp(path.join(os.tmpdir(), 'jumpshell-cfg-'));
  const configPath = path.join(tmpDir, 'config.json');
  outputChannel.appendLine(`[configure] Using ${cliCommand}, output → ${configPath}`);

  // Run ai-cli as the shell process so the terminal closes when it exits.
  const terminal = vscode.window.createTerminal({
    name: 'JumpShell Configure',
    shellPath: cliCommand,
    shellArgs: ['--configure', '--json', '-o', configPath],
    isTransient: true
  });

  terminal.show();

  let handled = false;

  const processConfigFile = async (): Promise<void> => {
    if (handled) {
      return;
    }

    handled = true;

    try {
      const exists = await fs.access(configPath).then(() => true, () => false);
      if (!exists) {
        outputChannel.appendLine('[configure] No configuration file was created.');
        return;
      }

      const raw = await fs.readFile(configPath, 'utf8');
      if (!raw.trim()) {
        outputChannel.appendLine('[configure] Configuration file is empty.');
        return;
      }

      const config = JSON.parse(raw) as Record<string, unknown>;
      let storedCount = 0;

      for (const [key, value] of Object.entries(config)) {
        if (typeof value === 'string' && value) {
          await context.secrets.store(key, value);
          storedCount += 1;
          outputChannel.appendLine(`[configure] Stored secret: ${key}`);
        }
      }

      if (storedCount > 0) {
        void vscode.window.showInformationMessage(
          `JumpShell securely stored ${storedCount} backend credential(s).`
        );
      }
      else {
        void vscode.window.showInformationMessage('JumpShell: no credentials were configured.');
      }
    }
    catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      outputChannel.appendLine(`[configure] Error: ${message}`);
      void vscode.window.showErrorMessage(`JumpShell configure: ${message}`);
    }
    finally {
      await fs.rm(tmpDir, { recursive: true, force: true });
    }
  };

  // Watch the temp directory for config.json creation.
  let fsWatcher: FSWatcher | undefined;
  try {
    fsWatcher = watch(tmpDir, (_event, filename) => {
      if (filename === 'config.json') {
        fsWatcher?.close();
        fsWatcher = undefined;
        // Brief delay to let the write flush.
        setTimeout(() => void processConfigFile(), 300);
      }
    });
  }
  catch {
    outputChannel.appendLine('[configure] fs.watch unavailable, falling back to terminal-close detection.');
  }

  // Fallback: process when the terminal is closed by the user.
  const terminalDisposable = vscode.window.onDidCloseTerminal(async (closed) => {
    if (closed !== terminal) {
      return;
    }

    terminalDisposable.dispose();
    fsWatcher?.close();

    // Brief delay for any pending file I/O.
    setTimeout(() => void processConfigFile(), 500);
  });

  context.subscriptions.push(terminalDisposable);
}
