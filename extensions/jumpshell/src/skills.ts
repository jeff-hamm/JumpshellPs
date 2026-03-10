import { promises as fs } from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { getOutputChannel } from './output';
import { pathExists, collectFiles, hashFiles, copyDirectory, shouldIgnoreName, revealInFileExplorer } from './utils';
import { installMcpConfig } from './mcp';
import { ensureRecommendedSettings } from './settings';

type SkillManifestEntry = {
  name: string;
  relativePath: string;
  hash: string;
  fileCount: number;
};

type SkillSource = {
  kind: 'assets' | 'repo';
  rootPath: string;
  manifestPath?: string;
};

type InstalledSkill = {
  hash: string;
  relativePath: string;
};

type InstallReceipt = {
  extensionVersion: string;
  installedAt: string;
  sourceKind: SkillSource['kind'];
  targetDir: string;
  skills: Record<string, InstalledSkill>;
};

const receiptFileName = 'install-receipt.json';

export async function installManagedSkills(context: vscode.ExtensionContext, mode: 'install' | 'update'): Promise<void> {
  const outputChannel = getOutputChannel();
  const skillSource = await resolveSkillSource(context);
  const manifest = await loadManifest(skillSource);
  if (manifest.length === 0) {
    throw new Error(`No skills were found in ${skillSource.rootPath}.`);
  }

  const targetDir = resolveTargetSkillsDir();
  await fs.mkdir(targetDir, { recursive: true });

  const existingReceipt = await loadReceipt(context);
  const currentSkillNames = new Set(manifest.map((entry) => entry.name));
  const staleSkillNames = Object.keys(existingReceipt?.skills ?? {}).filter((skillName) => !currentSkillNames.has(skillName));

  const conflicts = [] as string[];
  for (const entry of manifest) {
    const targetSkillDir = path.join(targetDir, entry.relativePath);
    const targetExists = await pathExists(targetSkillDir);
    const installedSkill = existingReceipt?.skills[entry.name];
    const isManaged = Boolean(installedSkill && installedSkill.relativePath === entry.relativePath);
    const isAlreadyCurrent = Boolean(isManaged && installedSkill?.hash === entry.hash && targetExists);
    if (isAlreadyCurrent) {
      continue;
    }

    if (targetExists && !isManaged) {
      conflicts.push(entry.name);
    }
  }

  let overwriteConflicts = false;
  let skipConflicts = false;
  if (conflicts.length > 0) {
    const choice = await vscode.window.showWarningMessage(
      `JumpShell found ${conflicts.length} existing skill folder(s) that are not marked as extension-managed.`,
      { modal: true },
      'Overwrite',
      'Skip conflicts',
      'Cancel'
    );

    if (!choice || choice === 'Cancel') {
      return;
    }

    overwriteConflicts = choice === 'Overwrite';
    skipConflicts = choice === 'Skip conflicts';
  }

  const installedSkills: Record<string, InstalledSkill> = {};
  let installedCount = 0;
  let updatedCount = 0;
  let skippedCount = 0;
  let removedStaleCount = 0;

  if (existingReceipt) {
    for (const staleSkillName of staleSkillNames) {
      const staleSkill = existingReceipt.skills[staleSkillName];
      const stalePath = path.join(existingReceipt.targetDir, staleSkill.relativePath);
      if (await pathExists(stalePath)) {
        await fs.rm(stalePath, { recursive: true, force: true });
        outputChannel.appendLine(`[remove] ${stalePath}`);
        removedStaleCount += 1;
      }
    }
  }

  for (const entry of manifest) {
    const sourceSkillDir = path.join(skillSource.rootPath, entry.relativePath);
    const targetSkillDir = path.join(targetDir, entry.relativePath);
    const targetExists = await pathExists(targetSkillDir);
    const previouslyInstalled = existingReceipt?.skills[entry.name];
    const isManaged = Boolean(previouslyInstalled && previouslyInstalled.relativePath === entry.relativePath);
    const isAlreadyCurrent = Boolean(isManaged && previouslyInstalled?.hash === entry.hash && targetExists);

    if (isAlreadyCurrent) {
      installedSkills[entry.name] = {
        hash: entry.hash,
        relativePath: entry.relativePath
      };
      skippedCount += 1;
      continue;
    }

    if (targetExists && !isManaged && skipConflicts) {
      outputChannel.appendLine(`[skip] ${targetSkillDir}`);
      skippedCount += 1;
      continue;
    }

    if (targetExists && (!isManaged || overwriteConflicts || previouslyInstalled)) {
      await fs.rm(targetSkillDir, { recursive: true, force: true });
    }

    await copyDirectory(sourceSkillDir, targetSkillDir);
    installedSkills[entry.name] = {
      hash: entry.hash,
      relativePath: entry.relativePath
    };

    if (isManaged) {
      updatedCount += 1;
      outputChannel.appendLine(`[update] ${targetSkillDir}`);
    }
    else {
      installedCount += 1;
      outputChannel.appendLine(`[install] ${targetSkillDir}`);
    }
  }

  const receipt: InstallReceipt = {
    extensionVersion: String(context.extension.packageJSON.version ?? '0.0.0'),
    installedAt: new Date().toISOString(),
    sourceKind: skillSource.kind,
    targetDir,
    skills: installedSkills
  };

  await saveReceipt(context, receipt);

  try {
    await ensureRecommendedSettings({ silent: true });
  }
  catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    outputChannel.appendLine(`[warn] Settings update skipped: ${message}`);
  }

  const autoInstallMcp = vscode.workspace.getConfiguration('jumpshell').get<boolean>('installMcpOnSkillsInstall', false);
  if (autoInstallMcp) {
    try {
      await installMcpConfig(context, { silent: true });
    }
    catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      outputChannel.appendLine(`[warn] MCP config install skipped: ${message}`);
    }
  }

  const summary = `${mode === 'install' ? 'Installed' : 'Updated'} JumpShell skills in ${targetDir}. Installed ${installedCount}, updated ${updatedCount}, skipped ${skippedCount}, removed stale ${removedStaleCount}.`;
  const action = await vscode.window.showInformationMessage(summary, 'Open folder');
  if (action === 'Open folder') {
    await revealInFileExplorer(targetDir);
  }
}

export async function removeManagedSkills(context: vscode.ExtensionContext): Promise<void> {
  const outputChannel = getOutputChannel();
  const receipt = await loadReceipt(context);
  if (!receipt || Object.keys(receipt.skills).length === 0) {
    void vscode.window.showInformationMessage('JumpShell has no managed skills to remove.');
    return;
  }

  const confirmation = await vscode.window.showWarningMessage(
    `Remove ${Object.keys(receipt.skills).length} JumpShell-managed skill folder(s) from ${receipt.targetDir}?`,
    { modal: true },
    'Remove'
  );

  if (confirmation !== 'Remove') {
    return;
  }

  let removedCount = 0;
  for (const skill of Object.values(receipt.skills)) {
    const skillPath = path.join(receipt.targetDir, skill.relativePath);
    if (await pathExists(skillPath)) {
      await fs.rm(skillPath, { recursive: true, force: true });
      outputChannel.appendLine(`[remove] ${skillPath}`);
      removedCount += 1;
    }
  }

  await deleteReceipt(context);
  void vscode.window.showInformationMessage(`Removed ${removedCount} JumpShell-managed skill folder(s).`);
}

export async function openSkillsFolder(): Promise<void> {
  const targetDir = resolveTargetSkillsDir();
  await fs.mkdir(targetDir, { recursive: true });
  await revealInFileExplorer(targetDir);
}

async function resolveSkillSource(context: vscode.ExtensionContext): Promise<SkillSource> {
  const assetsRoot = path.join(context.extensionPath, 'assets', 'skills');
  const assetsManifest = path.join(context.extensionPath, 'assets', 'skills-manifest.json');
  if (await pathExists(assetsRoot)) {
    return {
      kind: 'assets',
      rootPath: assetsRoot,
      manifestPath: assetsManifest
    };
  }

  const repoSkillsRoot = path.resolve(context.extensionPath, '..', '..', 'skills');
  if (await pathExists(repoSkillsRoot)) {
    return {
      kind: 'repo',
      rootPath: repoSkillsRoot
    };
  }

  throw new Error('No bundled skill assets or repository skills folder could be found. Run the build first or open the jumpshell repo.');
}

async function loadManifest(skillSource: SkillSource): Promise<SkillManifestEntry[]> {
  if (skillSource.manifestPath && await pathExists(skillSource.manifestPath)) {
    const raw = await fs.readFile(skillSource.manifestPath, 'utf8');
    const parsed = JSON.parse(raw) as { skills?: SkillManifestEntry[] };
    if (Array.isArray(parsed.skills)) {
      return parsed.skills;
    }
  }

  return buildManifest(skillSource.rootPath);
}

async function buildManifest(rootPath: string): Promise<SkillManifestEntry[]> {
  const entries = await fs.readdir(rootPath, { withFileTypes: true });
  const skills = [] as SkillManifestEntry[];

  for (const entry of entries.filter((candidate) => candidate.isDirectory()).sort((left, right) => left.name.localeCompare(right.name))) {
    if (shouldIgnoreName(entry.name)) {
      continue;
    }

    const skillRoot = path.join(rootPath, entry.name);
    const files = await collectFiles(skillRoot, skillRoot);
    skills.push({
      name: entry.name,
      relativePath: entry.name,
      hash: await hashFiles(skillRoot, files),
      fileCount: files.length
    });
  }

  return skills;
}

function resolveTargetSkillsDir(): string {
  const configuredPath = vscode.workspace.getConfiguration('jumpshell').get<string>('skillsPath', '~/.agents/skills').trim();
  if (!configuredPath || configuredPath === '~') {
    return path.join(os.homedir(), '.agents', 'skills');
  }

  if (configuredPath.startsWith('~/') || configuredPath.startsWith('~\\')) {
    return path.join(os.homedir(), configuredPath.slice(2));
  }

  if (path.isAbsolute(configuredPath)) {
    return configuredPath;
  }

  return path.resolve(os.homedir(), configuredPath);
}

async function loadReceipt(context: vscode.ExtensionContext): Promise<InstallReceipt | undefined> {
  const receiptPath = getReceiptPath(context);
  if (!await pathExists(receiptPath)) {
    return undefined;
  }

  try {
    const raw = await fs.readFile(receiptPath, 'utf8');
    return JSON.parse(raw) as InstallReceipt;
  }
  catch (error) {
    getOutputChannel().appendLine(`[warn] Failed to read install receipt: ${error instanceof Error ? error.message : String(error)}`);
    return undefined;
  }
}

async function saveReceipt(context: vscode.ExtensionContext, receipt: InstallReceipt): Promise<void> {
  await fs.mkdir(context.globalStorageUri.fsPath, { recursive: true });
  await fs.writeFile(getReceiptPath(context), JSON.stringify(receipt, null, 2) + '\n', 'utf8');
}

async function deleteReceipt(context: vscode.ExtensionContext): Promise<void> {
  await fs.rm(getReceiptPath(context), { force: true });
}

function getReceiptPath(context: vscode.ExtensionContext): string {
  return path.join(context.globalStorageUri.fsPath, receiptFileName);
}
