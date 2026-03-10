if ($env:TERM_PROGRAM -eq "vscode" -and -not $global:__VSCodeShellIntegrationLoaded) { 
    # Load cached values and get VS Code shell integration path
    # If not cached, the scriptblock will be executed and the result persisted
    $integrationPath = Get-JumpValue -Name "VSCODE_SHELL_INTEGRATION_PATH" -Default {
        code --locate-shell-integration-path pwsh
    }
    
    # Source the shell integration script in GLOBAL scope
    # This is important because the script defines the 'prompt' function
    # which must be in global scope for PowerShell to use it
    if ($integrationPath -and (Test-Path $integrationPath)) {
        $global:__VSCodeShellIntegrationLoaded = $true
        & ([scriptblock]::Create(". '$integrationPath'"))
    }
}

function Get-ConfigFile() {
    if ($Env:XDG_CONFIG_HOME) {
        $cfgPath = Join-Path $Env:XDG_CONFIG_HOME "config.json"
    } else {
        $cfgPath = Join-Path $HOME ".copilot/config.json"
    }
    if (-not (Test-Path $cfgPath)) {
        New-Item -ItemType File -Path $cfgPath -Force | Out-Null
        "{}" | Out-File -FilePath $cfgPath -Encoding UTF8
    }
    return $cfgPath
}

function Init() {
    $Env:COPILOT_ALLOW_ALL = (cat (Get-ConfigFile) | ConvertFrom-Json)?.allow_all_tools ?? "true";
}

function Set-Model([string]$Model) {
    $configFile = Get-ConfigFile
   
    $config = cat $configFile | ConvertFrom-Json
    $config.model = $Model
    $config | ConvertTo-Json | Out-File -FilePath $configFile -Encoding UTF8
}
function Add-TrustedFolder([string[]]$Paths) {
    $configFile = Get-ConfigFile
   
    $config = cat $configFile | ConvertFrom-Json
    if (-not $config.trusted_folders) {
        $config.trusted_folders = @()
    }
    foreach ($Path in $Paths) {
        if ($Path -notin $config.trusted_folders) {
            $config.trusted_folders += $Path
        }
    }
    $config | ConvertTo-Json | Out-File -FilePath $configFile -Encoding UTF8
}

<#
.SYNOPSIS
    PowerShell wrapper for GitHub Copilot CLI - An AI-powered coding assistant

.DESCRIPTION
    This function provides a PowerShell wrapper for the GitHub Copilot CLI with parameter validation and easy access to all options.

.PARAMETER AddDir
    Add a directory to the allowed list for file access (can be used multiple times)

.PARAMETER AllowAllTools
    Allow all tools to run automatically without confirmation; required for non-interactive mode

.PARAMETER AllowTool
    Allow specific tools

.PARAMETER Banner
    Show the startup banner

.PARAMETER Continue
    Resume the most recent session

.PARAMETER DenyTool
    Deny specific tools, takes precedence over --allow-tool or --allow-all-tools

.PARAMETER DisableMcpServer
    Disable a specific MCP server (can be used multiple times)

.PARAMETER Help
    Display help for command

.PARAMETER LogDir
    Set log file directory (default: ~/.copilot/logs/)

.PARAMETER LogLevel
    Set the log level (error, warning, info, debug, all, default, none)

.PARAMETER Model
    Set the AI model to use (claude-sonnet-4.5, claude-sonnet-4, or gpt-5)

.PARAMETER NoColor
    Disable all color output

.PARAMETER Prompt
    Execute a prompt directly without interactive mode

.PARAMETER Resume
    Resume from a previous session (optionally specify session ID)

.PARAMETER ScreenReader
    Enable screen reader optimizations

.PARAMETER Version
    Show version information

.EXAMPLE
    Invoke-Copilot -Prompt "Create a PowerShell function to get file sizes"
    
.EXAMPLE
    Invoke-Copilot -Continue
    
.EXAMPLE
    Invoke-Copilot -Model "claude-sonnet-4.5" -AllowAllTools

.EXAMPLE
    Invoke-Copilot -AddDir "C:\Projects" -LogLevel "debug"

.NOTES
    Requires GitHub Copilot CLI to be installed and available in PATH
#>
function Invoke-Copilot {
    [CmdletBinding(DefaultParameterSetName = 'Interactive')]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Prompt')]
        [string]$Prompt,
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'Prompt')]
        [string[]]$AddDir,
        
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'Prompt')]
        [switch]$AllowAllTools,
        
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'Prompt')]
        [string[]]$AllowTool,
        
        [Parameter(ParameterSetName = 'Interactive')]
        [switch]$Banner,
        
        [Parameter(ParameterSetName = 'Prompt')]
        [Parameter(ParameterSetName = 'Interactive')]
        [switch]$Continue,
        
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'Prompt')]
        [string[]]$DenyTool,
        
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'Prompt')]
        [string[]]$DisableMcpServer,
        
        [Parameter(ParameterSetName = 'Help')]
        [switch]$Help,
        
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'Prompt')]
        [string]$LogDir,
        
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'Prompt')]
        [ValidateSet('error', 'warning', 'info', 'debug', 'all', 'default', 'none')]
        [string]$LogLevel,
        
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'Prompt')]
        [ValidateSet('claude-sonnet-4.5', 'claude-sonnet-4', 'gpt-5')]
        [string]$Model,
        
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'Prompt')]
        [switch]$NoColor,
                
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'Prompt')]
        [string]$Resume,
        
        [Parameter(ParameterSetName = 'Interactive')]
        [Parameter(ParameterSetName = 'Prompt')]
        [switch]$ScreenReader,
        
        [Parameter(ParameterSetName = 'Version')]
        [switch]$Version
 )
    
    # Check if copilot is available
    if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
        Write-Error "GitHub Copilot CLI is not installed or not available in PATH. Please install it first."
        return
    }
    
    # Build the command arguments
    $arguments = @()
    
    # Handle parameter sets and specific parameters
    switch ($PSCmdlet.ParameterSetName) {
        'Help' {
            $arguments += '--help'
        }
        'Version' {
            $arguments += '--version'
        }
        'Prompt' {
            $arguments += '--prompt', $Prompt
        }
    }
    if ($Resume) {
        $arguments += '--resume', $Resume
    }
    elseif($Continue) {
        $arguments += '--continue'
    }

    
    # Add directory access
    if ($AddDir) {
        foreach ($dir in $AddDir) {
            $arguments += '--add-dir', $dir
        }
    }
    
    # Tool permissions
    if ($AllowAllTools) {
        $arguments += '--allow-all-tools'
    }
    
    if ($AllowTool) {
        $arguments += '--allow-tool'
        $arguments += $AllowTool
    }
    
    if ($DenyTool) {
        $arguments += '--deny-tool'
        $arguments += $DenyTool
    }
    
    # MCP server management
    if ($DisableMcpServer) {
        foreach ($server in $DisableMcpServer) {
            $arguments += '--disable-mcp-server', $server
        }
    }
    
    # UI options
    if ($Banner) {
        $arguments += '--banner'
    }
    
    if ($NoColor) {
        $arguments += '--no-color'
    }
    
    if ($ScreenReader) {
        $arguments += '--screen-reader'
    }
    
    # Configuration options
    if ($LogDir) {
        $arguments += '--log-dir', $LogDir
    }
    
    if ($LogLevel) {
        $arguments += '--log-level', $LogLevel
    }
    
    if ($Model) {
        $arguments += '--model', $Model
    }
    
    # Execute the command
    Write-Debug "Executing: copilot $($arguments -join ' ')"
    
    try {
        & copilot @arguments
    }
    catch {
        Write-Error "Failed to execute copilot command: $_"
    }
}


<#
.SYNOPSIS
    Simplified PowerShell wrapper for GitHub Copilot CLI that defaults to prompt mode

.DESCRIPTION
    This function provides a simplified interface to GitHub Copilot CLI that defaults to prompt mode.
    The first string argument is automatically treated as the prompt.

.PARAMETER Prompt
    The prompt to send to Copilot. Can be provided as the first positional parameter.

.PARAMETER AddDir
    Add a directory to the allowed list for file access (can be used multiple times)

.PARAMETER NoDefaultTools
    Disable automatic tool allowance. By default, all tools are allowed unless this switch is used.

.PARAMETER AllowTool
    Allow specific tools

.PARAMETER Clean
    Start a new session instead of continuing the previous one

.PARAMETER DenyTool
    Deny specific tools

.PARAMETER DisableMcpServer
    Disable a specific MCP server (can be used multiple times)

.PARAMETER LogDir
    Set log file directory

.PARAMETER LogLevel
    Set the log level (error, warning, info, debug, all, default, none)

.PARAMETER Model
    Set the AI model to use (claude-sonnet-4.5, claude-sonnet-4, or gpt-5)

.PARAMETER NoColor
    Disable all color output

.PARAMETER ScreenReader
    Enable screen reader optimizations

.EXAMPLE
    Prompt-Copilot "Create a PowerShell function to get file sizes"
    
.EXAMPLE
    Prompt-Copilot -Clean "Help me with git commands"
    
.EXAMPLE
    Prompt-Copilot -Model "claude-sonnet-4.5" -NoDefaultTools -AllowTool "file-reader" "Analyze this code"

.NOTES
    This is a simplified wrapper around Invoke-Copilot that defaults to prompt mode
#>
function Prompt-Copilot {
    [CmdletBinding()]
    param(
        [alias("Cwd")]
        [string]$Prompt,

        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $validModels = @('claude-sonnet-4.5', 'claude-sonnet-4', 'gpt-5')
            $validModels | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object { "'$_'" }
        })]
        [string]$Model,
        
        [string[]]$AddDir,
                
        [string[]]$AllowTool,
        [string]$Resume,
        [switch]$NewContext,
        
        [string[]]$DenyTool,
        
        [string[]]$DisableMcpServer,
        
        [string]$LogDir,
        
        [ValidateSet('error', 'warning', 'info', 'debug', 'all', 'default', 'none')]
        [string]$LogLevel,
        
        [switch]$NoDefaultTools,
        
        [switch]$NoColor,
        
        [switch]$ScreenReader
    )
    
    # Initialize CP_PATH for directory handling
    $CP_PATH = $null
    
    # Check if $Prompt is a directory path
    if ($Prompt -and (Test-Path $Prompt -PathType Container)) {
        $CP_PATH = $Prompt
        Push-Location $CP_PATH
        $Prompt = ""
        Add-TrustedFolder -Paths $CP_PATH
    }
    
    try {
        # Build parameters for Invoke-Copilot
        $invokeParams = @{}
        
        # Add prompt if provided
        if ($Prompt) {
            $invokeParams['Prompt'] = $Prompt
        }
        
        # Add directory access
        if ($AddDir) {
            $invokeParams['AddDir'] = $AddDir
            Add-TrustedFolder -Paths $AddDir
        }
        
        # Handle tool permissions logic
        # Allow all tools by default unless NoDefaultTools is specified
        $shouldAllowAllTools = (-not $NoDefaultTools) -or ($AllowTool -and $AllowTool.Length -gt 0)
        
        if ($shouldAllowAllTools) {
            $invokeParams['AllowAllTools'] = $true
        }
        
        if ($AllowTool) {
            $invokeParams['AllowTool'] = $AllowTool
        }
        
        if ($DenyTool) {
            $invokeParams['DenyTool'] = $DenyTool
        }
        
        # MCP server management
        if ($DisableMcpServer) {
            $invokeParams['DisableMcpServer'] = $DisableMcpServer
        }
        
        # Handle Clean switch - if Clean is specified, don't continue
        if (-not $NewContext) {
            if($Resume) {
                $invokeParams['Resume'] = $Resume
            }
            else {
                $invokeParams['Continue'] = $true
            }
        }
        
        # UI options
        if ($NoColor) {
            $invokeParams['NoColor'] = $true
        }
        
        if ($ScreenReader) {
            $invokeParams['ScreenReader'] = $true
        }
        
        # Configuration options
        if ($LogDir) {
            $invokeParams['LogDir'] = $LogDir
        }
        
        if ($LogLevel) {
            $invokeParams['LogLevel'] = $LogLevel
        }
        
        if ($Model) {
            $invokeParams['Model'] = $Model
            Set-Model -Model $Model
        }
        
        # Call the original function
        Invoke-Copilot @invokeParams
    }
    finally {
        if ($CP_PATH) {
            Pop-Location
        }
    }
}

<#
.SYNOPSIS
    Installs npm and GitHub Copilot CLI on a remote Linux machine via SSH

.DESCRIPTION
    This function connects to a Linux machine via SSH and automatically installs:
    - npm (if not already installed)
    - GitHub Copilot CLI (if not already installed)
    - Sets up the GH_TOKEN environment variable from the local machine

.PARAMETER Host
    The hostname or IP address of the remote Linux machine

.PARAMETER User
    The username to use for SSH connection (defaults to current user)

.PARAMETER Port
    The SSH port to use (defaults to 22)

.PARAMETER KeyFile
    Path to SSH private key file (optional)

.PARAMETER Password
    Password for SSH connection (optional, will prompt if needed)

.PARAMETER GHToken
    GitHub token to set on remote machine (defaults to $ENV:GH_TOKEN)

.EXAMPLE
    Install-CopilotOnRemote -Host "192.168.1.100" -User "ubuntu"
    
.EXAMPLE
    Install-CopilotOnRemote -Host "myserver.com" -User "admin" -KeyFile "~/.ssh/id_rsa"

.EXAMPLE
    Install-CopilotOnRemote -Host "server" -User "user" -GHToken "ghp_xxxxxxxxxxxx"
#>
function Install-CopilotOnRemote {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Host,
        
        [Parameter(Mandatory = $false)]
        [string]$User = $env:USERNAME,
        
        [Parameter(Mandatory = $false)]
        [int]$Port = 22,
        
        [Parameter(Mandatory = $false)]
        [string]$KeyFile,
        
        [Parameter(Mandatory = $false)]
        [string]$Password,
        
        [Parameter(Mandatory = $false)]
        [string]$GHToken = $env:GH_TOKEN
    )

    if (-not $GHToken) {
        throw "GH_TOKEN environment variable is not set and no token provided"
    }

    # Build SSH command
    $sshArgs = @()
    if ($Port -ne 22) {
        $sshArgs += "-p", $Port
    }
    if ($KeyFile) {
        $sshArgs += "-i", $KeyFile
    }
    
    $sshTarget = "${User}@${Host}"
    
    Write-Host "Connecting to $sshTarget..." -ForegroundColor Cyan

    # Create installation script
    $installScript = @'
#!/bin/bash
set -e

echo "=== Remote Installation Script Started ==="

# Function to detect the Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo $ID
    elif type lsb_release >/dev/null 2>&1; then
        lsb_release -si | tr '[:upper:]' '[:lower:]'
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

# Function to install Node.js and npm
install_npm() {
    echo "=== Checking for npm installation ==="
    
    if command -v npm >/dev/null 2>&1; then
        echo "npm is already installed: $(npm --version)"
        return 0
    fi
    
    echo "npm not found. Installing Node.js and npm..."
    
    DISTRO=$(detect_distro)
    echo "Detected distribution: $DISTRO"
    
    case $DISTRO in
        ubuntu|debian)
            echo "Installing Node.js via apt..."
            sudo apt update
            sudo apt install -y curl
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt install -y nodejs
            ;;
        centos|rhel|fedora)
            echo "Installing Node.js via yum/dnf..."
            if command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y curl
                curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
                sudo dnf install -y nodejs npm
            else
                sudo yum install -y curl
                curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
                sudo yum install -y nodejs npm
            fi
            ;;
        arch)
            echo "Installing Node.js via pacman..."
            sudo pacman -Sy --noconfirm nodejs npm
            ;;
        alpine)
            echo "Installing Node.js via apk..."
            sudo apk add --no-cache nodejs npm
            ;;
        *)
            echo "Unsupported distribution: $DISTRO"
            echo "Attempting to install via NodeSource universal installer..."
            curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
            sudo apt install -y nodejs || {
                echo "Failed to install Node.js. Please install manually."
                exit 1
            }
            ;;
    esac
    
    # Verify installation
    if command -v npm >/dev/null 2>&1; then
        echo "npm successfully installed: $(npm --version)"
        echo "Node.js version: $(node --version)"
    else
        echo "Failed to install npm"
        exit 1
    fi
}

# Function to install GitHub Copilot CLI
install_copilot_cli() {
    echo "=== Checking for GitHub Copilot CLI installation ==="
    
    if command -v copilot >/dev/null 2>&1; then
        echo "GitHub Copilot CLI is already installed: $(copilot --version)"
        return 0
    fi
    
    echo "GitHub Copilot CLI not found. Installing..."
    
    # Install npm if needed
    install_npm

    # Install via npm
    npm install -g @githubnext/github-copilot-cli
    
    # Verify installation
    if command -v copilot >/dev/null 2>&1; then
        echo "GitHub Copilot CLI successfully installed: $(copilot --version)"
    else
        echo "Failed to install GitHub Copilot CLI"
        exit 1
    fi
}

# Function to set up GitHub token environment variable
setup_gh_token() {
    echo "=== Setting up GitHub token environment variable ==="
    
    local token="$1"
    if [ -z "$token" ]; then
        echo "No GitHub token provided"
        return 1
    fi
    
    # Detect shell and set up environment variable accordingly
    local shell_name=$(basename "$SHELL")
    local profile_file=""
    
    case $shell_name in
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                profile_file="$HOME/.bashrc"
            elif [ -f "$HOME/.bash_profile" ]; then
                profile_file="$HOME/.bash_profile"
            else
                profile_file="$HOME/.profile"
            fi
            ;;
        zsh)
            profile_file="$HOME/.zshrc"
            ;;
        fish)
            # For fish shell, use a different approach
            if command -v fish >/dev/null 2>&1; then
                fish -c "set -Ux GH_TOKEN $token"
                echo "GitHub token set for fish shell"
                return 0
            fi
            profile_file="$HOME/.profile"
            ;;
        *)
            profile_file="$HOME/.profile"
            ;;
    esac
    
    # Check if GH_TOKEN is already set in the profile
    if [ -f "$profile_file" ] && grep -q "GH_TOKEN" "$profile_file"; then
        echo "GH_TOKEN already exists in $profile_file. Updating..."
        # Remove existing GH_TOKEN lines and add new one
        grep -v "GH_TOKEN" "$profile_file" > "${profile_file}.tmp" && mv "${profile_file}.tmp" "$profile_file"
    fi
    
    # Add the GitHub token to the profile
    echo "" >> "$profile_file"
    echo "# GitHub Token for Copilot CLI" >> "$profile_file"
    echo "export GH_TOKEN=\"$token\"" >> "$profile_file"
    
    echo "GitHub token added to $profile_file"
    
    # Also try systemd user environment (for systemd-based systems)
    if command -v systemctl >/dev/null 2>&1 && systemctl --user status >/dev/null 2>&1; then
        local env_dir="$HOME/.config/environment.d"
        mkdir -p "$env_dir"
        echo "GH_TOKEN=$token" > "$env_dir/gh_token.conf"
        echo "GitHub token also added to systemd user environment"
    fi
    
    # Set for current session
    export GH_TOKEN="$token"
    echo "GitHub token set for current session"
}

# Main execution
main() {
    local gh_token="$1"
    
    echo "Starting installation process..."
    
    # Install GitHub Copilot CLI if needed
    install_copilot_cli
    
    # Set up GitHub token
    if [ -n "$gh_token" ]; then
        setup_gh_token "$gh_token"
    else
        echo "No GitHub token provided, skipping token setup"
    fi
    
    echo "=== Installation completed successfully! ==="
    echo ""
    echo "To use GitHub Copilot CLI:"
    echo "1. Source your profile: source ~/.bashrc (or ~/.zshrc, etc.)"
    echo "2. Or start a new shell session"
    echo "3. Run: github-copilot-cli"
    echo ""
    echo "Installed versions:"
    echo "- Node.js: $(node --version)"
    echo "- npm: $(npm --version)"
    echo "- GitHub Copilot CLI: $(github-copilot-cli --version)"
}

# Run main function with GitHub token as argument
main "$1"
'@

    # Save the script to a temporary file with Linux line endings
    $tempScript = [System.IO.Path]::GetTempFileName() + ".sh"
    $installScript  -replace "`r`n", "`n" | Out-File -FilePath $tempScript -NoNewline
    try {
        Write-Host "Copying installation script to remote host..." -ForegroundColor Yellow
        
        # Copy the script to remote host
        $scpArgs = @()
        if ($Port -ne 22) {
            $scpArgs += "-P", $Port
        }
        if ($KeyFile) {
            $scpArgs += "-i", $KeyFile
        }
        
        $scpCommand = "scp"
        $scpCommand += " " + ($scpArgs -join " ")
        $scpCommand += " `"$tempScript`" `"${sshTarget}:install_copilot.sh`""
        
        Write-Debug "SCP Command: $scpCommand"
        Invoke-Expression $scpCommand
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to copy installation script to remote host"
        }
        
        Write-Host "Executing installation script on remote host..." -ForegroundColor Yellow
        
        # Execute the script on remote host
        $sshCommand = "ssh"
        $sshCommand += " " + ($sshArgs -join " ")
        $sshCommand += " `"$sshTarget`" `"chmod +x ./install_copilot.sh && ./install_copilot.sh '$GHToken'`""
        
        Write-Debug "SSH Command: $sshCommand"
        Invoke-Expression $sshCommand
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "Installation completed successfully!" -ForegroundColor Green
            Write-Host "GitHub Copilot CLI is now available on $Host" -ForegroundColor Green
            
            # Clean up the remote script
            $cleanupCommand = "ssh"
            $cleanupCommand += " " + ($sshArgs -join " ")
            $cleanupCommand += " `"$sshTarget`" `"rm -f /tmp/install_copilot.sh`""
            Invoke-Expression $cleanupCommand | Out-Null
        } else {
            throw "Installation script failed with exit code $LASTEXITCODE"
        }
        
    } catch {
        Write-Error "Failed to install Copilot CLI on remote host: $_"
        throw
    } finally {
        # Clean up local temp file
        if (Test-Path $tempScript) {
            Remove-Item $tempScript -Force
        }
    }
}

# Create additional aliases for the simplified function
Set-Alias -Name co -Value Prompt-Copilot
Set-Alias -Name ai -Value Prompt-Copilot
# # Create alias for shorter usage
Set-Alias -Name cplt -Value Prompt-Copilot

# Export all aliases to make them available when the module is imported
#Export-ModuleMember -Alias copilot-ps, pscp, co, ai
