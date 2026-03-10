import * as path from 'node:path';
import * as vscode from 'vscode';
import { getOutputChannel } from './output';
import { pathExists, execFileAsync } from './utils';
import { checkSkillsStatus, installManagedSkills } from './skills';
import { checkMcpConfigured, installMcpConfig } from './mcp';
import { resolveAiCli } from './configure';
import { installAiBackends } from './aiBackends';
import { checkPsModuleInstalled, installPowerShellModule } from './psModule';
import { runStartupUpdateCheck } from './updater';

async function resolveRepoRoot(context: vscode.ExtensionContext): Promise<string | undefined> {
  // Explicit user config takes priority.
  const configured = vscode.workspace.getConfiguration('jumpshell').get<string>('moduleRootPath', '').trim();
  if (configured) {
    const candidate = configured;
    if (await pathExists(path.join(candidate, '.git'))) {
      return candidate;
    }
    // moduleRootPath might point to src/pwsh — walk up to repo root.
    for (let up = candidate, prev = ''; up !== prev; prev = up, up = path.dirname(up)) {
      if (await pathExists(path.join(up, '.git'))) {
        return up;
      }
    }
  }

  // Dev-mode: extension lives inside the repo's extensions/ folder.
  const devRoot = path.resolve(context.extensionPath, '..', '..');
  if (await pathExists(path.join(devRoot, '.git'))) {
    return devRoot;
  }

  return undefined;
}

export async function updateJumpShell(context: vscode.ExtensionContext): Promise<void> {
  const outputChannel = getOutputChannel();
  outputChannel.show(true);

  // ── 1. Check for a new extension version on GitHub ──────────────────────────
  outputChannel.appendLine('[update] Checking GitHub for extension update…');
  try {
    await runStartupUpdateCheck(context);
  }
  catch (error) {
    outputChannel.appendLine(`[update] Extension update check failed: ${error instanceof Error ? error.message : String(error)}`);
  }

  // ── 2. Try to find the local git repo and pull ──────────────────────────────
  const repoRoot = await resolveRepoRoot(context);

  if (repoRoot) {
    outputChannel.appendLine(`[update] Repo found at ${repoRoot}`);

    // Check for remote changes first.
    try {
      await execFileAsync('git', ['-C', repoRoot, 'fetch', '--quiet'], { timeout: 15000 });
    }
    catch (error) {
      outputChannel.appendLine(`[update] git fetch failed: ${error instanceof Error ? error.message : String(error)}`);
    }

    let behindCount = 0;
    try {
      const { stdout } = await execFileAsync(
        'git', ['-C', repoRoot, 'rev-list', '--count', 'HEAD..@{u}'],
        { timeout: 5000 }
      );
      behindCount = parseInt(stdout.trim(), 10) || 0;
    }
    catch {
      // upstream may not exist; treat as up to date
    }

    if (behindCount > 0) {
      const choice = await vscode.window.showInformationMessage(
        `JumpShell repo has ${behindCount} new commit(s). Pull now?`,
        'Pull',
        'Skip'
      );

      if (choice === 'Pull') {
        outputChannel.appendLine('[update] Running git pull…');
        try {
          const { stdout, stderr } = await execFileAsync('git', ['-C', repoRoot, 'pull', '--ff-only'], { timeout: 30000 });
          if (stdout.trim()) { outputChannel.appendLine(stdout.trim()); }
          if (stderr.trim()) { outputChannel.appendLine(stderr.trim()); }
        }
        catch (error) {
          const msg = error instanceof Error ? error.message : String(error);
          outputChannel.appendLine(`[update] git pull failed: ${msg}`);
          void vscode.window.showWarningMessage(`JumpShell: git pull failed — ${msg}`);
        }
      }
    }
    else {
      outputChannel.appendLine('[update] Repo is up to date.');
    }
  }
  else {
    outputChannel.appendLine('[update] No local git repo found — skipping git pull.');
  }

  // ── 3. Refresh what was previously installed ────────────────────────────────
  const [skillsStatus, mcpConfigured, aiCli, psInstalled] = await Promise.all([
    checkSkillsStatus(context).catch(() => ({ installed: false, upToDate: true, installedCount: 0, updateCount: 0 })),
    checkMcpConfigured().catch(() => false as boolean),
    resolveAiCli().catch(() => undefined as string | undefined),
    checkPsModuleInstalled().catch(() => false as boolean),
  ]);

  const tasks: Array<{ label: string; run: () => Promise<void> }> = [];

  if (skillsStatus.installed) {
    if (!skillsStatus.upToDate) {
      tasks.push({ label: `Skills (${skillsStatus.updateCount} update(s))`, run: () => installManagedSkills(context, 'update') });
    } else {
      outputChannel.appendLine(`[update] Skills: ${skillsStatus.installedCount} installed, up to date.`);
    }
  }

  if (mcpConfigured) {
    tasks.push({ label: 'MCP Configuration', run: () => installMcpConfig(context, { silent: true }) });
  }

  if (aiCli) {
    tasks.push({ label: 'AI Backends (ai-cli)', run: () => installAiBackends(context, { silent: true }) });
  }

  if (psInstalled) {
    tasks.push({ label: 'PowerShell Module', run: () => installPowerShellModule(context) });
  }

  if (tasks.length === 0) {
    void vscode.window.showInformationMessage('JumpShell: Everything is up to date.');
    return;
  }

  const labelList = tasks.map((t) => t.label).join(', ');
  const choice = await vscode.window.showInformationMessage(
    `JumpShell: Update ${labelList}?`,
    'Update All',
    'Cancel'
  );

  if (choice !== 'Update All') {
    return;
  }

  for (const task of tasks) {
    outputChannel.appendLine(`[update] Updating: ${task.label}`);
    try {
      await task.run();
    }
    catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      outputChannel.appendLine(`[update] Error updating ${task.label}: ${msg}`);
      const cont = await vscode.window.showErrorMessage(
        `JumpShell Update — ${task.label}: ${msg}`,
        'Continue',
        'Stop'
      );
      if (cont !== 'Continue') {
        break;
      }
    }
  }
}
