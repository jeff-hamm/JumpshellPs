import { promises as fs } from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import * as vscode from 'vscode';
import { getOutputChannel } from './output';
import { isRecord, fetchJson, downloadFile, execFileAsync } from './utils';

type GitHubReleaseAsset = {
  name?: string;
  browser_download_url?: string;
};

type GitHubRelease = {
  tag_name?: string;
  name?: string;
  prerelease?: boolean;
  draft?: boolean;
  html_url?: string;
  assets?: GitHubReleaseAsset[];
};

const lastUpdateCheckStateKey = 'lastUpdateCheckTimestamp';
const defaultUpdateCheckCooldownMs = 24 * 60 * 60 * 1000;

export async function runStartupUpdateCheck(context: vscode.ExtensionContext): Promise<void> {
  const outputChannel = getOutputChannel();
  try {
    const lastCheck = context.globalState.get<number>(lastUpdateCheckStateKey, 0);
    if (Date.now() - lastCheck < defaultUpdateCheckCooldownMs) {
      return;
    }

    await context.globalState.update(lastUpdateCheckStateKey, Date.now());

    const repoSlug = resolveExtensionReleaseRepo(context);
    const includePreReleases = vscode.workspace.getConfiguration('jumpshell').get<boolean>('includePreReleaseUpdates', false);
    const release = await getLatestRelease(repoSlug, includePreReleases);
    if (!release) {
      return;
    }

    const currentVersion = String(context.extension.packageJSON.version ?? '0.0.0');
    const latestVersion = normalizeVersionString(release.tag_name ?? release.name ?? '');
    if (!latestVersion || compareSemver(currentVersion, latestVersion) >= 0) {
      return;
    }

    const extensionName = String(context.extension.packageJSON.name ?? 'jumpshell');
    const vsixAsset = pickVsixAsset(release, extensionName);
    if (!vsixAsset?.browser_download_url || !vsixAsset.name) {
      return;
    }

    const action = await vscode.window.showInformationMessage(
      `JumpShell ${latestVersion} is available (current: ${currentVersion}).`,
      'Install update',
      'View release',
      'Dismiss'
    );

    if (action === 'Install update') {
      await downloadAndInstallRelease(context, release, vsixAsset, latestVersion);
    }
    else if (action === 'View release' && release.html_url) {
      await vscode.env.openExternal(vscode.Uri.parse(release.html_url));
    }
  }
  catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    outputChannel.appendLine(`[update-check] Startup check failed: ${message}`);
  }
}

export async function checkForExtensionUpdates(context: vscode.ExtensionContext): Promise<void> {
  const repoSlug = resolveExtensionReleaseRepo(context);
  const includePreReleases = vscode.workspace.getConfiguration('jumpshell').get<boolean>('includePreReleaseUpdates', false);
  const release = await getLatestRelease(repoSlug, includePreReleases);
  if (!release) {
    void vscode.window.showWarningMessage(`JumpShell could not find a release in ${repoSlug}.`);
    return;
  }

  const currentVersion = String(context.extension.packageJSON.version ?? '0.0.0');
  const latestVersion = normalizeVersionString(release.tag_name ?? release.name ?? '');
  if (!latestVersion) {
    throw new Error(`Latest release tag '${release.tag_name ?? release.name ?? 'unknown'}' is not a semver version.`);
  }

  if (compareSemver(currentVersion, latestVersion) >= 0) {
    void vscode.window.showInformationMessage(`JumpShell is up to date. Current version: ${currentVersion}.`);
    return;
  }

  const extensionName = String(context.extension.packageJSON.name ?? 'jumpshell');
  const vsixAsset = pickVsixAsset(release, extensionName);
  if (!vsixAsset?.browser_download_url || !vsixAsset.name) {
    throw new Error(`Release ${release.tag_name ?? release.name ?? 'unknown'} has no VSIX asset.`);
  }

  const action = await vscode.window.showInformationMessage(
    `JumpShell ${latestVersion} is available (current: ${currentVersion}). Install now?`,
    'Install',
    'View release'
  );

  if (!action) {
    return;
  }

  if (action === 'View release') {
    if (release.html_url) {
      await vscode.env.openExternal(vscode.Uri.parse(release.html_url));
    }
    return;
  }

  await downloadAndInstallRelease(context, release, vsixAsset, latestVersion);
}

async function downloadAndInstallRelease(
  context: vscode.ExtensionContext,
  _release: GitHubRelease,
  vsixAsset: GitHubReleaseAsset,
  latestVersion: string
): Promise<void> {
  const tempDir = await fs.mkdtemp(path.join(os.tmpdir(), 'jumpshell-update-'));
  const vsixPath = path.join(tempDir, vsixAsset.name!);

  try {
    await downloadFile(vsixAsset.browser_download_url!, vsixPath);
    await installVsix(vsixPath);
    await context.globalState.update(lastUpdateCheckStateKey, Date.now());

    const reloadAction = await vscode.window.showInformationMessage(
      `JumpShell ${latestVersion} was installed. Reload window to activate the update.`,
      'Reload Window'
    );

    if (reloadAction === 'Reload Window') {
      await vscode.commands.executeCommand('workbench.action.reloadWindow');
    }
  }
  finally {
    await fs.rm(tempDir, { recursive: true, force: true });
  }
}

function resolveExtensionReleaseRepo(context: vscode.ExtensionContext): string {
  const configuredRepo = vscode.workspace.getConfiguration('jumpshell').get<string>('extensionReleaseRepo', '').trim();
  if (configuredRepo) {
    return configuredRepo;
  }

  const repositoryField = context.extension.packageJSON.repository;
  const repositoryUrl = typeof repositoryField === 'string' ? repositoryField : repositoryField?.url;
  const parsed = parseGitHubRepoSlug(repositoryUrl);
  if (parsed) {
    return parsed;
  }

  return 'jeff-hamm/JumpshellPs';
}

function parseGitHubRepoSlug(repositoryUrl: unknown): string | undefined {
  if (typeof repositoryUrl !== 'string' || !repositoryUrl.trim()) {
    return undefined;
  }

  const trimmed = repositoryUrl.trim();
  const withoutGit = trimmed.endsWith('.git') ? trimmed.slice(0, -4) : trimmed;
  const httpsMatch = withoutGit.match(/github\.com[/:]([^/]+)\/([^/]+)$/i);
  if (!httpsMatch) {
    return undefined;
  }

  return `${httpsMatch[1]}/${httpsMatch[2]}`;
}

async function getLatestRelease(repoSlug: string, includePreReleases: boolean): Promise<GitHubRelease | undefined> {
  if (!includePreReleases) {
    try {
      const latest = await fetchJson(`https://api.github.com/repos/${repoSlug}/releases/latest`);
      return isRecord(latest) ? latest as GitHubRelease : undefined;
    }
    catch {
      return undefined;
    }
  }

  const releasesResponse = await fetchJson(`https://api.github.com/repos/${repoSlug}/releases?per_page=30`);
  if (!Array.isArray(releasesResponse)) {
    return undefined;
  }

  const candidates = releasesResponse
    .filter((entry) => isRecord(entry))
    .map((entry) => entry as GitHubRelease)
    .filter((entry) => !entry.draft)
    .map((entry) => ({ release: entry, version: normalizeVersionString(entry.tag_name ?? entry.name ?? '') }))
    .filter((entry) => Boolean(entry.version)) as Array<{ release: GitHubRelease; version: string }>;

  candidates.sort((left, right) => compareSemver(right.version, left.version));
  return candidates[0]?.release;
}

function pickVsixAsset(release: GitHubRelease, extensionName: string): GitHubReleaseAsset | undefined {
  const assets = Array.isArray(release.assets) ? release.assets : [];
  const exactPrefix = `${extensionName}-`;
  const exact = assets.find((asset) => {
    if (typeof asset.name !== 'string') {
      return false;
    }

    const name = asset.name.toLowerCase();
    return name.endsWith('.vsix') && name.startsWith(exactPrefix.toLowerCase());
  });

  if (exact) {
    return exact;
  }

  return assets.find((asset) => typeof asset.name === 'string' && asset.name.toLowerCase().endsWith('.vsix'));
}

function normalizeVersionString(value: string): string | undefined {
  const match = value.trim().match(/^v?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$/);
  if (!match) {
    return undefined;
  }

  return `${Number.parseInt(match[1], 10)}.${Number.parseInt(match[2], 10)}.${Number.parseInt(match[3], 10)}`;
}

function compareSemver(left: string, right: string): number {
  const leftParts = left.split('.').map((entry) => Number.parseInt(entry, 10));
  const rightParts = right.split('.').map((entry) => Number.parseInt(entry, 10));

  for (let index = 0; index < 3; index += 1) {
    const leftPart = Number.isFinite(leftParts[index]) ? leftParts[index] : 0;
    const rightPart = Number.isFinite(rightParts[index]) ? rightParts[index] : 0;
    if (leftPart !== rightPart) {
      return leftPart - rightPart;
    }
  }

  return 0;
}

async function installVsix(vsixPath: string): Promise<void> {
  try {
    await vscode.commands.executeCommand('workbench.extensions.installExtension', vscode.Uri.file(vsixPath));
    return;
  }
  catch {
    getOutputChannel().appendLine('[warn] VS Code command install failed, attempting CLI install fallback.');
  }

  const candidates = process.platform === 'win32'
    ? ['code-insiders', 'code', 'cursor']
    : ['code-insiders', 'code', 'cursor'];

  for (const candidate of candidates) {
    try {
      await execFileAsync(candidate, ['--install-extension', vsixPath, '--force'], {
        timeout: 120000,
        windowsHide: true,
        maxBuffer: 1024 * 1024
      });
      return;
    }
    catch {
      continue;
    }
  }

  throw new Error('Failed to install the downloaded VSIX. Install it manually via Extensions: Install from VSIX...');
}
