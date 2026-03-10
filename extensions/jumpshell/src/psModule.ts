import * as path from 'node:path';
import * as vscode from 'vscode';
import { getOutputChannel } from './output';
import { pathExists, execFileAsync } from './utils';
import { ensurePwsh } from './prereqs';

export async function checkPsModuleInstalled(): Promise<boolean> {
  const pwsh = process.platform === 'win32' ? 'pwsh.exe' : 'pwsh';
  try {
    const { stdout } = await execFileAsync(
      pwsh,
      ['-NoProfile', '-NonInteractive', '-Command',
        'Get-Module Jumpshell -ListAvailable | Select-Object -First 1 -ExpandProperty Name'],
      { timeout: 8000, windowsHide: true }
    );
    return Boolean(stdout.trim());
  }
  catch {
    return false;
  }
}

async function resolvePwshRoot(context: vscode.ExtensionContext): Promise<string | undefined> {
  const bundled = path.join(context.extensionPath, 'assets', 'src', 'pwsh');
  if (await pathExists(bundled)) {
    return bundled;
  }
  // Dev mode fallback: use the workspace source tree directly
  const dev = path.resolve(context.extensionPath, '..', '..', 'src', 'pwsh');
  if (await pathExists(dev)) {
    return dev;
  }
  return undefined;
}

export async function installPowerShellModule(context: vscode.ExtensionContext): Promise<void> {
  const outputChannel = getOutputChannel();

  // Ensure pwsh is on PATH before we try to open a pwsh terminal.
  const pwshAvailable = await ensurePwsh();
  if (!pwshAvailable) {
    outputChannel.appendLine('[ps-module] pwsh not available — skipping module install');
    return;
  }

  const pwshRoot = await resolvePwshRoot(context);
  const installScript = pwshRoot ? path.join(pwshRoot, 'Install.ps1') : undefined;
  const hasInstallScript = installScript ? await pathExists(installScript) : false;

  outputChannel.appendLine(`[ps-module] pwshRoot=${pwshRoot ?? 'not found'}, installScript=${hasInstallScript}`);

  // Step 1: Modify $PROFILE to add Import-Module Jumpshell -Force
  const profileLines = [
    `$_line = 'Import-Module Jumpshell -Force'`,
    `if (-not (Test-Path $PROFILE)) { New-Item -Path $PROFILE -ItemType File -Force | Out-Null }`,
    `$_cur = Get-Content -LiteralPath $PROFILE -Raw -ErrorAction SilentlyContinue`,
    `if ($_cur -notmatch [regex]::Escape($_line)) {`,
    `  Add-Content -Path $PROFILE -Value "\`n$_line"`,
    `  Write-Host "Added '$_line' to $PROFILE" -ForegroundColor Green`,
    `} else {`,
    `  Write-Host "'$_line' already in profile" -ForegroundColor DarkCyan`,
    `}`,
  ].join('\n');

  // Step 2: Run Install.ps1
  let installLines: string;
  if (hasInstallScript) {
    const escaped = installScript!.replace(/'/g, "''");
    installLines = `& '${escaped}'`;
  } else {
    installLines = [
      `$_m = Get-Module Jumpshell -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1`,
      `if ($_m) { & (Join-Path $_m.ModuleBase 'Install.ps1') }`,
      `else { Write-Warning 'Jumpshell module not found — run the installer manually.' }`,
    ].join('\n');
  }

  const terminal = vscode.window.createTerminal({
    name: 'Jumpshell — Install PowerShell Module',
    shellPath: process.platform === 'win32' ? 'pwsh.exe' : 'pwsh',
    isTransient: false,
  });
  terminal.show();
  terminal.sendText(profileLines);
  terminal.sendText(installLines);
}
