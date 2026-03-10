import * as path from 'node:path';
import * as vscode from 'vscode';
import { getOutputChannel } from './output';
import { pathExists } from './utils';

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

  const isWindows = process.platform === 'win32';
  const terminal = vscode.window.createTerminal({
    name: 'JumpShell — Install ai-backends',
    shellPath: isWindows ? 'pwsh.exe' : undefined,
    isTransient: true,
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
      'JumpShell: Installing ai-backends (ai-cli) — check the terminal for progress.'
    );
  }
}
