import * as vscode from 'vscode';
import { initOutputChannel } from './output';
import { installManagedSkills } from './skills';
import { installMcpConfig } from './mcp';
import { runStartupUpdateCheck, checkForExtensionUpdates } from './updater';
import { ensureRecommendedSettings } from './settings';
import { configureJumpshell } from './configure';
import { registerModelPickerCommands } from './modelPicker';
import { registerHotkeyCommands } from './hotkey';

let outputChannel: vscode.OutputChannel;

export function activate(context: vscode.ExtensionContext): void {
  outputChannel = vscode.window.createOutputChannel('JumpShell');
  context.subscriptions.push(outputChannel);
  initOutputChannel(outputChannel);

  context.subscriptions.push(
    registerCommand('jumpshell.installSkills', () => installManagedSkills(context, 'install')),
    registerCommand('jumpshell.updateSkills', () => installManagedSkills(context, 'update')),
    registerCommand('jumpshell.installJumpshellMcp', () => installMcpConfig(context)),
    registerCommand('jumpshell.configureJumpshell', () => configureJumpshell(context)),
    registerCommand('jumpshell.checkExtensionUpdates', () => checkForExtensionUpdates(context))
  );

  registerModelPickerCommands(context, outputChannel);

  void ensureRecommendedSettings({ silent: true });
  void runStartupUpdateCheck(context);
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
