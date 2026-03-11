import * as vscode from 'vscode';
import { getOutputChannel } from './output';
import { checkSkillsStatus, installManagedSkills } from './skills';
import { checkMcpConfigured, installMcpConfig } from './mcp';
import { resolveAiCli } from './configure';
import { installAiBackends, configureAiCli } from './aiBackends';
import { checkPsModuleInstalled, installPowerShellModule } from './psModule';

const SETUP_SELECTIONS_KEY = 'jumpshell.setupSelections';

type SetupItem = vscode.QuickPickItem & {
  id: string;
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

  const savedSelections = context.globalState.get<Record<string, boolean>>(SETUP_SELECTIONS_KEY, {});

  /** Use saved preference if present; otherwise fall back to `defaultPicked`. */
  const resolvePicked = (id: string, defaultPicked: boolean): boolean =>
    id in savedSelections ? savedSelections[id] : defaultPicked;

  const items: SetupItem[] = [];

  // --- Skills ---
  if (!skillsStatus.installed) {
    items.push({
      id: 'skills',
      label: '$(package) Skills',
      description: 'Not installed',
      detail: 'Install Jumpshell Copilot skill pack to ~/.agents/skills',
      picked: resolvePicked('skills', true),
      run: () => installManagedSkills(context, 'install'),
    });
  } else if (!skillsStatus.upToDate) {
    items.push({
      id: 'skills',
      label: '$(sync) Skills',
      description: `${skillsStatus.updateCount} update(s) available`,
      detail: `${skillsStatus.installedCount} skill(s) installed — updates are ready`,
      picked: resolvePicked('skills', true),
      run: () => installManagedSkills(context, 'update'),
    });
  } else {
    items.push({
      id: 'skills',
      label: '$(pass-filled) Skills',
      description: `${skillsStatus.installedCount} skill(s) — up to date`,
      picked: resolvePicked('skills', false),
      run: () => installManagedSkills(context, 'update'),
    });
  }

  // --- MCP Configuration ---
  if (!mcpConfigured) {
    items.push({
      id: 'mcp',
      label: '$(plug) MCP Configuration',
      description: 'Not configured',
      detail: 'Configure the JumpshellPs MCP server in mcp.json',
      picked: resolvePicked('mcp', true),
      run: () => installMcpConfig(context),
    });
  } else {
    items.push({
      id: 'mcp',
      label: '$(pass-filled) MCP Configuration',
      description: 'Configured',
      picked: resolvePicked('mcp', false),
      run: () => installMcpConfig(context),
    });
  }

  // --- AI Backends ---
  let aiBackendsItem: SetupItem;
  if (!aiCli) {
    aiBackendsItem = {
      id: 'ai-backends',
      label: '$(cloud-download) AI Backends (ai-cli)',
      description: 'Not installed',
      detail: 'Install the bundled ai-backends Python package and ai-cli tool',
      picked: resolvePicked('ai-backends', true),
      run: () => installAiBackends(context),
    };
  } else {
    aiBackendsItem = {
      id: 'ai-backends',
      label: '$(pass-filled) AI Backends (ai-cli)',
      description: `${aiCli} is on PATH`,
      picked: resolvePicked('ai-backends', false),
      run: () => installAiBackends(context),
    };
  }
  items.push(aiBackendsItem);

  // --- PowerShell Module ---
  if (!psModuleInstalled) {
    items.push({
      id: 'ps-module',
      label: '$(terminal-powershell) PowerShell Module',
      description: 'Not installed',
      detail: 'Add Import-Module Jumpshell to $PROFILE and run Install.ps1',
      picked: resolvePicked('ps-module', true),
      run: () => installPowerShellModule(context),
    });
  } else {
    items.push({
      id: 'ps-module',
      label: '$(pass-filled) PowerShell Module',
      description: 'Installed',
      picked: resolvePicked('ps-module', false),
      run: () => installPowerShellModule(context),
    });
  }

  const selected = await vscode.window.showQuickPick(items, {
    canPickMany: true,
    title: 'Jumpshell Setup',
    placeHolder: 'Pre-checked items need attention — press Enter to run selected actions.',
  });

  if (!selected || selected.length === 0) {
    return;
  }

  // Persist this run's selections so the next open pre-checks the same items.
  const newSelections: Record<string, boolean> = {};
  for (const item of items) {
    newSelections[item.id] = selected.includes(item);
  }
  await context.globalState.update(SETUP_SELECTIONS_KEY, newSelections);

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

  // After setup, if the user ran the AI Backends install, offer configuration.
  if (selected.includes(aiBackendsItem)) {
    const action = await vscode.window.showInformationMessage(
      'Jumpshell: ai-backends is installing in the terminal. Configure API keys when ready.',
      'Configure Now'
    );
    if (action === 'Configure Now') {
      await configureAiCli(context);
    }
  }
}

