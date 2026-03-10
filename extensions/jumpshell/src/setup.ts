import * as vscode from 'vscode';
import { getOutputChannel } from './output';
import { checkSkillsStatus, installManagedSkills } from './skills';
import { checkMcpConfigured, installMcpConfig } from './mcp';
import { resolveAiCli } from './configure';
import { installAiBackends, configureAiCli } from './aiBackends';
import { checkPsModuleInstalled, installPowerShellModule } from './psModule';

type SetupItem = vscode.QuickPickItem & {
  run: () => Promise<void>;
};

export async function configureShell(context: vscode.ExtensionContext): Promise<void> {
  const outputChannel = getOutputChannel();

  const { skillsStatus, mcpConfigured, aiCli, psModuleInstalled } =
    await vscode.window.withProgress(
      {
        location: vscode.ProgressLocation.Notification,
        title: 'Jumpshell: Checking component status…',
        cancellable: false,
      },
      async () => {
        const [skillsStatus, mcpConfigured, aiCli, psModuleInstalled] = await Promise.all([
          checkSkillsStatus(context).catch(() => ({ installed: false, upToDate: false, installedCount: 0, updateCount: 0 })),
          checkMcpConfigured().catch(() => false as boolean),
          resolveAiCli().catch(() => undefined as string | undefined),
          checkPsModuleInstalled().catch(() => false as boolean),
        ]);
        return { skillsStatus, mcpConfigured, aiCli, psModuleInstalled };
      }
    );

  const items: SetupItem[] = [];

  // --- Skills ---
  if (!skillsStatus.installed) {
    items.push({
      label: '$(package) Skills',
      description: 'Not installed',
      detail: 'Install Jumpshell Copilot skill pack to ~/.agents/skills',
      picked: true,
      run: () => installManagedSkills(context, 'install'),
    });
  } else if (!skillsStatus.upToDate) {
    items.push({
      label: '$(sync) Skills',
      description: `${skillsStatus.updateCount} update(s) available`,
      detail: `${skillsStatus.installedCount} skill(s) installed — updates are ready`,
      picked: true,
      run: () => installManagedSkills(context, 'update'),
    });
  } else {
    items.push({
      label: '$(pass-filled) Skills',
      description: `${skillsStatus.installedCount} skill(s) — up to date`,
      picked: false,
      run: () => installManagedSkills(context, 'update'),
    });
  }

  // --- MCP Configuration ---
  if (!mcpConfigured) {
    items.push({
      label: '$(plug) MCP Configuration',
      description: 'Not configured',
      detail: 'Configure the JumpshellPs MCP server in mcp.json',
      picked: true,
      run: () => installMcpConfig(context),
    });
  } else {
    items.push({
      label: '$(pass-filled) MCP Configuration',
      description: 'Configured',
      picked: false,
      run: () => installMcpConfig(context),
    });
  }

  // --- AI Backends ---
  if (!aiCli) {
    items.push({
      label: '$(cloud-download) AI Backends (ai-cli)',
      description: 'Not installed',
      detail: 'Install the bundled ai-backends Python package and ai-cli tool',
      picked: true,
      run: () => installAiBackends(context),
    });
  } else {
    items.push({
      label: '$(pass-filled) AI Backends (ai-cli)',
      description: `${aiCli} is on PATH`,
      picked: false,
      run: () => installAiBackends(context),
    });
  }

  // --- PowerShell Module ---
  if (!psModuleInstalled) {
    items.push({
      label: '$(terminal-powershell) PowerShell Module',
      description: 'Not installed',
      detail: 'Add Import-Module Jumpshell to $PROFILE and run Install.ps1',
      picked: true,
      run: () => installPowerShellModule(context),
    });
  } else {
    items.push({
      label: '$(pass-filled) PowerShell Module',
      description: 'Installed',
      picked: false,
      run: () => installPowerShellModule(context),
    });
  }

  // --- Configure AI Backends ---
  // Always offered; pre-selected when no keys are stored yet (fresh install).
  items.push({
    label: '$(gear) Configure AI Backends Credentials',
    description: 'Select backends and enter your API keys',
    picked: !aiCli,
    run: () => configureAiCli(context),
  });

  const selected = await vscode.window.showQuickPick(items, {
    canPickMany: true,
    title: 'Jumpshell Setup',
    placeHolder: 'Pre-checked items need attention — press Enter to run selected actions.',
  });

  if (!selected || selected.length === 0) {
    return;
  }

  for (const item of selected) {
    outputChannel.appendLine(`[setup] Running: ${item.label}`);
    try {
      await item.run();
    }
    catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      outputChannel.appendLine(`[setup] Error: ${message}`);
      const cont = await vscode.window.showErrorMessage(
        `Jumpshell Setup — ${item.label.replace(/\$\([^)]+\)\s*/, '')}: ${message}`,
        'Continue',
        'Stop'
      );
      if (cont !== 'Continue') {
        break;
      }
    }
  }
}

