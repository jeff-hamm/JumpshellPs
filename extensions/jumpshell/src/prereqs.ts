import * as vscode from 'vscode';
import { getOutputChannel } from './output';
import { execFileAsync } from './utils';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

export async function commandExists(cmd: string, args: string[] = ['--version']): Promise<boolean> {
  try {
    await execFileAsync(cmd, args, { timeout: 6000, windowsHide: true });
    return true;
  }
  catch {
    return false;
  }
}

/**
 * Show a terminal, send lines, and wait for the user to close it (or just
 * return if we can't await — the caller handles that case).
 */
function openInstallTerminal(name: string, shellPath: string | undefined, lines: string[]): vscode.Terminal {
  const terminal = vscode.window.createTerminal({ name, shellPath, isTransient: false });
  terminal.show();
  for (const line of lines) {
    terminal.sendText(line);
  }
  return terminal;
}

// ─────────────────────────────────────────────────────────────────────────────
// PowerShell
// ─────────────────────────────────────────────────────────────────────────────

async function installPwshWindows(): Promise<void> {
  const terminal = openInstallTerminal(
    'Jumpshell — Install PowerShell',
    'cmd.exe',
    [
      'echo Installing PowerShell via winget...',
      'winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements',
    ]
  );

  await new Promise<void>((resolve) => {
    const disposable = vscode.window.onDidCloseTerminal((t) => {
      if (t === terminal) {
        disposable.dispose();
        resolve();
      }
    });
  });
}

async function installPwshMacOs(): Promise<void> {
  const hasBrew = await commandExists('brew', ['--version']);
  const lines: string[] = [];

  if (!hasBrew) {
    lines.push(
      'echo "Installing Homebrew..."',
      '/bin/zsh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
    );
  }

  lines.push(
    'echo "Installing PowerShell via Homebrew..."',
    'brew install --cask powershell',
  );

  const terminal = openInstallTerminal('Jumpshell — Install PowerShell', '/bin/zsh', lines);

  await new Promise<void>((resolve) => {
    const disposable = vscode.window.onDidCloseTerminal((t) => {
      if (t === terminal) {
        disposable.dispose();
        resolve();
      }
    });
  });
}

async function installPwshLinux(): Promise<void> {
  // Detect distro and pick the right install approach. We use a self-contained
  // shell snippet that falls through a chain of known package managers /
  // portable binary download as a last resort.
  const script = [
    '#!/bin/sh',
    'set -e',
    'echo "Detecting Linux distribution..."',
    '',
    'install_portable() {',
    '  echo "Falling back to portable PowerShell install..."',
    '  ARCH=$(uname -m)',
    '  case "$ARCH" in',
    '    x86_64)  ARCH_TAG="x64" ;;',
    '    aarch64) ARCH_TAG="arm64" ;;',
    '    armv7l)  ARCH_TAG="arm32" ;;',
    '    *)       echo "Unsupported arch: $ARCH"; return 1 ;;',
    '  esac',
    '  PWSH_VERSION=$(curl -sSL https://api.github.com/repos/PowerShell/PowerShell/releases/latest | grep \'"tag_name"\' | sed \'s/.*"v\\([^\"]*\\)".*/\\1/\')',
    '  URL="https://github.com/PowerShell/PowerShell/releases/download/v${PWSH_VERSION}/powershell-${PWSH_VERSION}-linux-${ARCH_TAG}.tar.gz"',
    '  DEST="$HOME/.local/share/powershell"',
    '  mkdir -p "$DEST"',
    '  curl -sSL "$URL" | tar -xz -C "$DEST"',
    '  PWSH_BIN="$HOME/.local/bin/pwsh"',
    '  mkdir -p "$(dirname "$PWSH_BIN")"',
    '  echo "#!/bin/sh\\nexec \\\"$DEST/pwsh\\\" \\\"\\$@\\\"" > "$PWSH_BIN"',
    '  chmod +x "$PWSH_BIN"',
    '  echo "PowerShell installed to $DEST"',
    '  echo "Add $HOME/.local/bin to your PATH if it is not already there."',
    '}',
    '',
    '# --- package-manager path ---',
    'if command -v apt-get >/dev/null 2>&1; then',
    '  . /etc/os-release',
    '  if [ "${ID:-}" = "debian" ]; then',
    '    REPO_URL="https://packages.microsoft.com/config/debian/${VERSION_ID}/packages-microsoft-prod.deb"',
    '  else',
    '    REPO_URL="https://packages.microsoft.com/config/ubuntu/${VERSION_ID}/packages-microsoft-prod.deb"',
    '  fi',
    '  if curl -fsSL "$REPO_URL" -o /tmp/packages-microsoft-prod.deb; then',
    '    sudo dpkg -i /tmp/packages-microsoft-prod.deb',
    '    sudo apt-get update',
    '    if ! sudo apt-get install -y powershell; then install_portable; fi',
    '  else',
    '    install_portable',
    '  fi',
    'elif command -v dnf >/dev/null 2>&1; then',
    '  curl -sSL https://packages.microsoft.com/config/rhel/8/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo',
    '  if ! sudo dnf install -y powershell; then install_portable; fi',
    'elif command -v yum >/dev/null 2>&1; then',
    '  curl -sSL https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo',
    '  if ! sudo yum install -y powershell; then install_portable; fi',
    'elif command -v zypper >/dev/null 2>&1; then',
    '  if ! sudo zypper install -y powershell; then install_portable; fi',
    'elif command -v pacman >/dev/null 2>&1; then',
    '  if ! (sudo pacman -Sy --noconfirm powershell-bin 2>/dev/null || sudo pacman -Sy --noconfirm powershell); then install_portable; fi',
    'elif command -v snap >/dev/null 2>&1; then',
    '  if ! sudo snap install powershell --classic; then install_portable; fi',
    'else',
    '  install_portable',
    'fi',
    '',
    'echo "Done. Run: pwsh"',
  ].join('\n');

  const terminal = openInstallTerminal('Jumpshell — Install PowerShell', '/bin/bash', [
    `bash -c '${script.replace(/'/g, "'\\''")}'`,
  ]);

  await new Promise<void>((resolve) => {
    const disposable = vscode.window.onDidCloseTerminal((t) => {
      if (t === terminal) {
        disposable.dispose();
        resolve();
      }
    });
  });
}

/**
 * Ensure `pwsh` (PowerShell 7+) is available.
 * Returns true if it is (or was just installed), false if the user cancelled.
 */
export async function ensurePwsh(): Promise<boolean> {
  const outputChannel = getOutputChannel();

  if (await commandExists('pwsh', ['--version'])) {
    return true;
  }

  outputChannel.appendLine('[prereqs] pwsh not found — offering installation');

  const choice = await vscode.window.showWarningMessage(
    'PowerShell (pwsh) is not installed. Install it now?',
    { modal: true },
    'Install',
    'Cancel'
  );

  if (choice !== 'Install') {
    return false;
  }

  const platform = process.platform;

  if (platform === 'win32') {
    await installPwshWindows();
  } else if (platform === 'darwin') {
    await installPwshMacOs();
  } else {
    await installPwshLinux();
  }

  // Re-check after installation attempt.
  const nowAvailable = await commandExists('pwsh', ['--version'])
    || (platform === 'linux' && await commandExists(`${process.env.HOME ?? '~'}/.local/bin/pwsh`, ['--version']));

  if (!nowAvailable) {
    void vscode.window.showWarningMessage(
      'PowerShell installation may not be complete yet. ' +
      'If the installer finished, reload VS Code and try again.'
    );
  }

  return nowAvailable;
}

// ─────────────────────────────────────────────────────────────────────────────
// Python
// ─────────────────────────────────────────────────────────────────────────────

/** Returns the usable python executable name, or undefined if not found. */
export async function resolvePython(): Promise<string | undefined> {
  for (const candidate of ['python3', 'python', 'py']) {
    try {
      const { stdout } = await execFileAsync(candidate, ['--version'], { timeout: 5000, windowsHide: true });
      // Reject Python 2.x
      if (/Python\s+3\./i.test(stdout)) {
        return candidate;
      }
    }
    catch {
      // not found
    }
  }
  return undefined;
}

async function installPythonWindows(): Promise<void> {
  const choice = await vscode.window.showInformationMessage(
    'Python 3 is not installed. Install via winget?',
    { modal: true },
    'winget install',
    'Open python.org',
    'Cancel'
  );

  if (choice === 'winget install') {
    const terminal = openInstallTerminal(
      'Jumpshell — Install Python',
      'cmd.exe',
      [
        'winget install --id Python.Python.3 --source winget --accept-package-agreements --accept-source-agreements',
        'echo Done. You may need to restart your terminal for python to be on PATH.',
      ]
    );
    await new Promise<void>((resolve) => {
      const d = vscode.window.onDidCloseTerminal((t) => { if (t === terminal) { d.dispose(); resolve(); } });
    });
  } else if (choice === 'Open python.org') {
    await vscode.env.openExternal(vscode.Uri.parse('https://www.python.org/downloads/'));
  }
}

async function installPythonMacOs(): Promise<void> {
  const hasBrew = await commandExists('brew', ['--version']);
  const lines: string[] = [];

  if (!hasBrew) {
    lines.push(
      'echo "Installing Homebrew first..."',
      '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
    );
  }

  lines.push('brew install python3');

  const terminal = openInstallTerminal('Jumpshell — Install Python', '/bin/bash', lines);
  await new Promise<void>((resolve) => {
    const d = vscode.window.onDidCloseTerminal((t) => { if (t === terminal) { d.dispose(); resolve(); } });
  });
}

async function installPythonLinux(): Promise<void> {
  const lines = [
    'set -e',
    'if command -v apt-get >/dev/null 2>&1; then sudo apt-get update && sudo apt-get install -y python3 python3-pip',
    'elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y python3 python3-pip',
    'elif command -v yum >/dev/null 2>&1; then sudo yum install -y python3 python3-pip',
    'elif command -v zypper >/dev/null 2>&1; then sudo zypper install -y python3 python3-pip',
    'elif command -v pacman >/dev/null 2>&1; then sudo pacman -Sy --noconfirm python python-pip',
    'elif command -v snap >/dev/null 2>&1; then sudo snap install python38',
    'else echo "Could not detect package manager. Install Python 3 manually."; exit 1',
    'fi',
  ].join('; ');

  const terminal = openInstallTerminal('Jumpshell — Install Python', '/bin/bash', [`bash -c '${lines}'`]);
  await new Promise<void>((resolve) => {
    const d = vscode.window.onDidCloseTerminal((t) => { if (t === terminal) { d.dispose(); resolve(); } });
  });
}

/**
 * Ensure Python 3 is available.
 * Returns the python command name if available (or after install), undefined if the user cancelled.
 */
export async function ensurePython(): Promise<string | undefined> {
  const outputChannel = getOutputChannel();

  const existing = await resolvePython();
  if (existing) {
    return existing;
  }

  outputChannel.appendLine('[prereqs] Python 3 not found — offering installation');

  const choice = await vscode.window.showWarningMessage(
    'Python 3 is not installed. It is required for ai-backends / ai-cli. Install it now?',
    { modal: true },
    'Install',
    'Cancel'
  );

  if (choice !== 'Install') {
    return undefined;
  }

  const platform = process.platform;
  if (platform === 'win32') {
    await installPythonWindows();
  } else if (platform === 'darwin') {
    await installPythonMacOs();
  } else {
    await installPythonLinux();
  }

  return resolvePython();
}

// ─────────────────────────────────────────────────────────────────────────────
// Node.js / npm
// ─────────────────────────────────────────────────────────────────────────────

async function installNodeWindows(): Promise<void> {
  const terminal = openInstallTerminal(
    'Jumpshell — Install Node.js',
    'cmd.exe',
    [
      'winget install --id OpenJS.NodeJS.LTS --source winget --accept-package-agreements --accept-source-agreements',
      'echo Done. You may need to restart your terminal for npm to be on PATH.',
    ]
  );
  await new Promise<void>((resolve) => {
    const d = vscode.window.onDidCloseTerminal((t) => { if (t === terminal) { d.dispose(); resolve(); } });
  });
}

async function installNodeMacOs(): Promise<void> {
  const hasBrew = await commandExists('brew', ['--version']);
  const lines: string[] = [];
  if (!hasBrew) {
    lines.push(
      'echo "Installing Homebrew first..."',
      '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"',
    );
  }
  lines.push('brew install node');
  const terminal = openInstallTerminal('Jumpshell — Install Node.js', '/bin/bash', lines);
  await new Promise<void>((resolve) => {
    const d = vscode.window.onDidCloseTerminal((t) => { if (t === terminal) { d.dispose(); resolve(); } });
  });
}

async function installNodeLinux(): Promise<void> {
  const lines = [
    'set -e',
    'if command -v apt-get >/dev/null 2>&1; then curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs',
    'elif command -v dnf >/dev/null 2>&1; then sudo dnf install -y nodejs',
    'elif command -v yum >/dev/null 2>&1; then sudo yum install -y nodejs',
    'elif command -v zypper >/dev/null 2>&1; then sudo zypper install -y nodejs',
    'elif command -v pacman >/dev/null 2>&1; then sudo pacman -Sy --noconfirm nodejs npm',
    'else echo Could not detect package manager. Install Node.js from https://nodejs.org; exit 1',
    'fi',
  ].join('; ');

  const terminal = openInstallTerminal('Jumpshell — Install Node.js', '/bin/bash', [`bash -c '${lines}'`]);
  await new Promise<void>((resolve) => {
    const d = vscode.window.onDidCloseTerminal((t) => { if (t === terminal) { d.dispose(); resolve(); } });
  });
}

/**
 * Ensure npm is available (requires Node.js).
 * Returns true if npm is (or was just) installed, false if the user cancelled.
 */
export async function ensureNpm(): Promise<boolean> {
  const outputChannel = getOutputChannel();

  if (await commandExists('npm', ['--version'])) {
    return true;
  }

  outputChannel.appendLine('[prereqs] npm not found — offering Node.js installation');

  const choice = await vscode.window.showWarningMessage(
    'npm (Node.js) is not installed. It is required for GitHub Copilot CLI. Install Node.js now?',
    { modal: true },
    'Install',
    'Cancel'
  );

  if (choice !== 'Install') {
    return false;
  }

  const platform = process.platform;
  if (platform === 'win32') {
    await installNodeWindows();
  } else if (platform === 'darwin') {
    await installNodeMacOs();
  } else {
    await installNodeLinux();
  }

  return commandExists('npm', ['--version']);
}
