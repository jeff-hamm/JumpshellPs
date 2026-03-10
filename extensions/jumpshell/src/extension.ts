import * as vscode from 'vscode';
import { initOutputChannel } from './output';
import { runStartupUpdateCheck } from './updater';
import { ensureRecommendedSettings } from './settings';
import { configureShell } from './setup';
import { updateJumpShell } from './update';
import { registerModelPickerCommands } from './modelPicker';
import { registerHotkeyCommands } from './hotkey';

const firstRunStateKey = 'hasRunSetup';

let outputChannel: vscode.OutputChannel;

export function activate(context: vscode.ExtensionContext): void {
  outputChannel = vscode.window.createOutputChannel('JumpShell');
  context.subscriptions.push(outputChannel);
  initOutputChannel(outputChannel);

  context.subscriptions.push(
    registerCommand('jumpshell.configureShell', () => configureShell(context)),
    registerCommand('jumpshell.updateJumpShell', () => updateJumpShell(context))
  );

  registerModelPickerCommands(context, outputChannel);

  void ensureRecommendedSettings({ silent: true });
  void runStartupUpdateCheck(context);

  // On first activation, open the setup wizard automatically.
  const hasRunSetup = context.globalState.get<boolean>(firstRunStateKey, false);
  if (!hasRunSetup) {
    void context.globalState.update(firstRunStateKey, true);
    void vscode.commands.executeCommand('jumpshell.configureShell');
  }
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
      void vscode.window.showErrorMessage(`JumpShell: ${message}`);
    }
  });
}
