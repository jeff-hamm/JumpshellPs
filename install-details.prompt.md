# Install Jumpshell Extension

Install the Jumpshell VS Code extension (`electric-pink.jumpshell`) into the detected editor.

## Determine the approach

**If the workspace root contains `Install.ps1` / `Install.sh`** (i.e. you are inside the Jumpshell repo), use those scripts — they handle everything automatically.

**If the repo is not present**, follow the manual steps in the [Manual install (no repo)](#manual-install-no-repo) section below.

---

## Install via repo scripts (preferred)

The scripts perform a four-tier fallback:
1. Local `.vsix` file next to the script
2. Download from the GitHub release matching the version in `extensions/jumpshell/package.json`
3. Direct VSIX download from the VS Code Marketplace API (see URL template below)
4. Marketplace install via the editor CLI (`--install-extension electric-pink.jumpshell`)

### Windows (PowerShell)

```powershell
.\Install.ps1
```

Or pass an explicit VSIX path:

```powershell
.\Install.ps1 -VsixPath path\to\jumpshell.vsix
```

### Linux / macOS (bash)

```bash
bash ./Install.sh
```

Or pass an explicit VSIX path:

```bash
bash ./Install.sh --vsix-path path/to/jumpshell.vsix
```

---

## Manual install (no repo)

Use this when the repository is not checked out.

### Step 1 — Detect the editor CLI

Run the relevant snippet for the current platform. Try each candidate in order and use the first one found.

**PowerShell:**
```powershell
$cli = @('cursor','windsurf','code-insiders','codium','code') |
    Where-Object { Get-Command $_ -ErrorAction SilentlyContinue } |
    Select-Object -First 1
if (-not $cli) { throw "No supported VS Code editor found in PATH." }
Write-Host "Editor CLI: $cli"
```

**bash/zsh:**
```bash
cli=""
for candidate in cursor windsurf code-insiders codium code; do
    if command -v "$candidate" &>/dev/null; then cli="$candidate"; break; fi
done
if [[ -z "$cli" ]]; then echo "ERROR: No supported editor found in PATH." >&2; exit 1; fi
echo "Editor CLI: $cli"
```

### Step 2 — Download the VSIX (try in order)

Try each source in sequence and stop at the first success.

#### 2a — GitHub release

Use the GitHub Releases API to find the latest version and download the VSIX asset.

**PowerShell:**
```powershell
$api     = Invoke-RestMethod 'https://api.github.com/repos/jeff-hamm/jumpshell/releases/latest'
$version = $api.tag_name -replace '^v', ''
$vsix    = "jumpshell-${version}.vsix"
$url     = "https://github.com/jeff-hamm/jumpshell/releases/download/v${version}/${vsix}"
$dest    = Join-Path $env:TEMP $vsix
try {
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    Write-Host "Downloaded from GitHub: $dest"
} catch {
    Write-Warning "GitHub download failed: $_"
    $dest = $null
}
```

**bash/zsh:**
```bash
version=$(curl -fsSL https://api.github.com/repos/jeff-hamm/jumpshell/releases/latest \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
vsix="jumpshell-${version}.vsix"
url="https://github.com/jeff-hamm/jumpshell/releases/download/v${version}/${vsix}"
dest="${TMPDIR:-/tmp}/${vsix}"
curl -fsSL -o "$dest" "$url" || dest=""
```

#### 2b — VS Code Marketplace direct download

If the GitHub download failed, download the VSIX directly from the Marketplace.

URL template:
```
https://marketplace.visualstudio.com/_apis/public/gallery/publishers/{publisher}/vsextensions/{name}/{version}/vspackage
```

For `electric-pink.jumpshell` (replace `{version}` with the actual version):
```
https://marketplace.visualstudio.com/_apis/public/gallery/publishers/electric-pink/vsextensions/jumpshell/{version}/vspackage
```

**PowerShell:**
```powershell
if (-not $dest) {
    # Query marketplace for latest version if unknown
    $marketUrl = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/electric-pink/vsextensions/jumpshell/${version}/vspackage"
    $dest = Join-Path $env:TEMP "jumpshell-${version}.vsix"
    try {
        Invoke-WebRequest -Uri $marketUrl -OutFile $dest -UseBasicParsing
        Write-Host "Downloaded from Marketplace: $dest"
    } catch {
        Write-Warning "Marketplace download failed: $_"
        $dest = $null
    }
}
```

**bash/zsh:**
```bash
if [[ -z "$dest" ]]; then
    market_url="https://marketplace.visualstudio.com/_apis/public/gallery/publishers/electric-pink/vsextensions/jumpshell/${version}/vspackage"
    dest="${TMPDIR:-/tmp}/jumpshell-${version}.vsix"
    curl -fsSL -o "$dest" "$market_url" || dest=""
fi
```

### Step 3 — Install the VSIX (or fall back to CLI)

If a VSIX was downloaded, install it. Otherwise use the editor CLI to pull from the marketplace.

**PowerShell:**
```powershell
if ($dest -and (Test-Path $dest)) {
    & $cli '--install-extension' $dest '--force'
} else {
    # Final fallback: let the editor CLI handle the download
    & $cli '--install-extension' 'electric-pink.jumpshell' '--force'
}
```

**bash/zsh:**
```bash
if [[ -n "$dest" && -f "$dest" ]]; then
    "$cli" --install-extension "$dest" --force
else
    # Final fallback: let the editor CLI handle the download
    "$cli" --install-extension electric-pink.jumpshell --force
fi
```

---

## Supported editors

| Editor | CLI command |
|---|---|
| VS Code | `code` |
| VS Code Insiders | `code-insiders` |
| Cursor | `cursor` |
| Windsurf | `windsurf` |
| VSCodium | `codium` |

All editors must have their CLI in `PATH`. This is done automatically by their installers.

After installation, reload the editor window (`Developer: Reload Window`) to activate the extension.
