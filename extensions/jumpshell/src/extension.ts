import * as vscode from 'vscode';
import { initOutputChannel } from './output';
import { runStartupUpdateCheck } from './updater';
import { ensureRecommendedSettings } from './settings';
import { configureShell } from './setup';
import { updateJumpshell } from './update';
import { registerModelPickerCommands } from './modelPicker';
import { registerHotkeyCommands } from './hotkey';
import { ensurePwsh } from './prereqs';

const firstRunStateKey = 'hasRunSetup';

let outputChannel: vscode.OutputChannel;

export function activate(context: vscode.ExtensionContext): void {
  outputChannel = vscode.window.createOutputChannel('Jumpshell');
  context.subscriptions.push(outputChannel);
  initOutputChannel(outputChannel);

  context.subscriptions.push(
    registerCommand('jumpshell.configureShell', () => configureShell(context)),
    registerCommand('jumpshell.updateJumpshell', () => updateJumpshell(context))
  );

  registerModelPickerCommands(context, outputChannel);
  registerHotkeyCommands(context, outputChannel);

  void runStartupTasks(context);
}

export function deactivate(): void {
  outputChannel?.dispose();
}

function registerCommand(id: string, handler: () => Promise<void> | void): vscode.Disposable {
  return vscode.commands.registerCommand(id, async () => {
    try {
      await handler();
    }
    catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      outputChannel.appendLine(`[error] ${id}: ${message}`);
      void vscode.window.showErrorMessage(`Jumpshell: ${message}`);
    }
  });
}

function runStartupTasks(context: vscode.ExtensionContext): void {
  void (async () => {
    try {
      await ensureRecommendedSettings({ silent: true });
    }
    catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      outputChannel.appendLine(`[startup] settings update failed: ${message}`);
    }

    try {
      const pwshAvailable = await ensurePwsh();
      outputChannel.appendLine(`[startup] pwsh ${pwshAvailable ? 'available' : 'not available'}`);
    }
    catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      outputChannel.appendLine(`[startup] pwsh check failed: ${message}`);
    }

    await runStartupUpdateCheck(context);

    // On first activation, open the setup wizard automatically.
    const hasRunSetup = context.globalState.get<boolean>(firstRunStateKey, false);
    if (!hasRunSetup) {
      await context.globalState.update(firstRunStateKey, true);
      await vscode.commands.executeCommand('jumpshell.configureShell');
    }
  })();
}
