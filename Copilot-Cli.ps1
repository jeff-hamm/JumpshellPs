
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

# Create additional aliases for the simplified function
Set-Alias -Name co -Value Prompt-Copilot
Set-Alias -Name ai -Value Prompt-Copilot
# # Create alias for shorter usage
Set-Alias -Name cplt -Value Prompt-Copilot

# Export all aliases to make them available when the module is imported
#Export-ModuleMember -Alias copilot-ps, pscp, co, ai
