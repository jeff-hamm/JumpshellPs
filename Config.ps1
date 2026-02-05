<#
.SYNOPSIS
    Gets the jumpshell directory path

.DESCRIPTION
    Returns the path to the jumpshell directory ($HOME/.jumpshell/)
    Creates the directory if it doesn't exist.

.EXAMPLE
    Get-JumpDir
    Returns: C:\Users\username\.jumpshell
#>
function Get-JumpDir() {
    $jumpshellDir = Join-Path $HOME ".jumpshell"
    
    # Create directory if it doesn't exist
    if (-not (Test-Path $jumpshellDir)) {
        New-Item -ItemType Directory -Path $jumpshellDir -Force | Out-Null
    }
    
    return $jumpshellDir
}

<#
.SYNOPSIS
    Gets the path to a specific .env file by type

.DESCRIPTION
    Returns the path to the specified .env file in $HOME/.jumpshell/
    Does not check if the file exists.

.PARAMETER Type
    Which .env file to return:
    - "Secret" - secret.env (for sensitive values)
    - "User" - .env (general user settings)
    - "Machine" - <COMPUTERNAME>.env (machine-specific settings)

.EXAMPLE
    Get-JumpEnvFile -Type Secret
    Returns: C:\Users\username\.jumpshell\secret.env
#>
function Get-JumpEnvFile {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet("Machine", "User", "Secret")]
        [string]$Type = "User"
    )
    
    $jumpshellDir = Get-JumpDir
    
    switch ($Type) {
        "Secret"  { return Join-Path $jumpshellDir "secret.env" }
        "User"    { return Join-Path $jumpshellDir ".env" }
        "Machine" { return Join-Path $jumpshellDir "$($env:COMPUTERNAME).env" }
    }
}

<#
.SYNOPSIS
    Gets the list of per-host .env files

.DESCRIPTION
    Returns a list of .env files in $HOME/.jumpshell/ that exist, in priority order:
    - secret.env (highest priority)
    - .env
    - <COMPUTERNAME>.env (lowest priority)

.PARAMETER Types
    Optional list of types to include. If not specified, all types are included.

.PARAMETER LowestPriorityFirst
    If specified, returns files in reverse order (lowest priority first).
    Useful for loading where you want higher priority files to override.

.EXAMPLE
    Get-JumpEnvFiles
    Returns: @("C:\Users\username\.jumpshell\secret.env", "C:\Users\username\.jumpshell\.env")

.EXAMPLE
    Get-JumpEnvFiles -Types Secret, User
    Returns only secret.env and .env if they exist

.EXAMPLE
    Get-JumpEnvFiles -LowestPriorityFirst
    Returns files in reverse order for loading (machine, user, secret)
#>
function Get-JumpEnvFiles {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet("Machine", "User", "Secret")]
        [string[]]$Types = @("Secret", "User", "Machine"),
        
        [switch]$LowestPriorityFirst
    )
    
    # Define files in priority order (highest priority first)
    $priorityOrder = @("Secret", "User", "Machine")
    
    # Filter and order the types
    $orderedTypes = $priorityOrder | Where-Object { $_ -in $Types }
    
    # Reverse if lowest priority first is requested
    if ($LowestPriorityFirst) {
        $orderedTypes = @($orderedTypes)
        [array]::Reverse($orderedTypes)
    }
    
    # Get files that exist
    $envFiles = $orderedTypes | ForEach-Object { Get-JumpEnvFile -Type $_ } | Where-Object { Test-Path $_ }
    
    return $envFiles
}

<#
.SYNOPSIS
    Sets a variable in multiple scopes

.DESCRIPTION
    Sets a variable with the given name and value in the specified PowerShell scopes
    and/or as an environment variable.

.PARAMETER Name
    The name of the variable to set

.PARAMETER Value
    The value to set

.PARAMETER Scopes
    List of scopes to set the variable in. Valid values:
    - "Global" - Set as global PowerShell variable
    - "Script" - Set as script-scoped PowerShell variable
    - "Local" - Set as local PowerShell variable
    - "Private" - Set as private PowerShell variable
    - "Env" or "Environment" - Set as environment variable
    Defaults to @("Global", "Env")

.PARAMETER PersistUserEnv
    If specified and Scopes includes Env/Environment, also persists the environment
    variable to the User level (survives logoff/reboot for current user)

.PARAMETER PersistMachineEnv
    If specified and Scopes includes Env/Environment, also persists the environment
    variable to the Machine level (survives logoff/reboot for all users, requires admin)

.EXAMPLE
    Set-VariableScopes -Name "MY_VAR" -Value "hello"
    Sets $global:MY_VAR and $env:MY_VAR to "hello"

.EXAMPLE
    Set-VariableScopes -Name "MY_VAR" -Value "hello" -Scopes @("Env")
    Sets only $env:MY_VAR to "hello"

.EXAMPLE
    Set-VariableScopes -Name "MY_VAR" -Value "hello" -PersistUserEnv
    Sets $env:MY_VAR and persists to user environment variables
#>
function Set-VariableScopes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,
        
        [Parameter(Mandatory = $true, Position = 1)]
        [AllowNull()]
        $Value,
        
        [Parameter(Position = 2)]
        [ValidateSet("Global", "Script", "Local", "Private", "Env", "Environment")]
        [string[]]$Scopes = @("Global", "Env"),
        
        [switch]$PersistUserEnv,
        
        [switch]$PersistMachineEnv
    )
    
    foreach ($scope in $Scopes) {
        switch ($scope) {
            { $_ -in @("Env", "Environment") } {
                # Always set in current process
                [Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
                
                # Optionally persist to User level
                if ($PersistUserEnv) {
                    [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
                }
                
                # Optionally persist to Machine level (requires admin)
                if ($PersistMachineEnv) {
                    if (Test-Admin) {
                        [Environment]::SetEnvironmentVariable($Name, $Value, 'Machine')
                    }
                    else {
                        # Elevate to set machine environment variable
                        $EscapedValue = $Value -replace "'", "''"
                        $Command = "[Environment]::SetEnvironmentVariable('$Name', '$EscapedValue', 'Machine')"
                        Invoke-Elevated -Command $Command -NoExitKey -NoWait
                    }
                }
            }
            { $_ -in @("Global", "Script", "Local", "Private") } {
                Set-Variable -Name $Name -Value $Value -Scope $scope
            }
        }
    }
}

<#
.SYNOPSIS
    Gets a value from the per-host .env files

.DESCRIPTION
    Searches through the .env files in priority order (secret.env, .env, <COMPUTERNAME>.env)
    and returns the first matching value for the specified key.
    If the value is not found and a Default is provided, returns the default.
    If the Default is a ScriptBlock, it is executed and the result is persisted.
    Does not set any variables - use Load-JumpValue to also set variables.

.PARAMETER Name
    The name of the environment variable to retrieve

.PARAMETER Default
    Default value to return if the key is not found.
    If this is a ScriptBlock, it will be executed and the result will be
    persisted to the .env file using Set-JumpValue.

.EXAMPLE
    Get-JumpValue -Name "VSCODE_SHELL_INTEGRATION_PATH"
    Returns the cached value for VSCODE_SHELL_INTEGRATION_PATH

.EXAMPLE
    Get-JumpValue -Name "MY_VALUE" -Default "fallback"
    Returns "fallback" if MY_VALUE is not set

.EXAMPLE
    Get-JumpValue -Name "COMPUTED_VALUE" -Default { Get-SomeExpensiveValue }
    Executes the scriptblock if not cached, persists the result, and returns it
#>
function Get-JumpValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,
        
        [Parameter(Position = 1)]
        $Default
    )
    
    # Call Load-JumpValue with empty scopes to just get the value without setting variables
    return Load-JumpValue -Name $Name -Default $Default -Scopes @()
}

<#
.SYNOPSIS
    Loads a value from the per-host .env files and sets it in specified scopes

.DESCRIPTION
    Searches through the .env files in priority order (secret.env, .env, <COMPUTERNAME>.env)
    and returns the first matching value for the specified key.
    If the value is not found and a Default is provided, returns the default.
    If the Default is a ScriptBlock, it is executed and the result is persisted.
    Sets the value in the specified PowerShell scopes and/or as an environment variable.

.PARAMETER Name
    The name of the variable to retrieve and set

.PARAMETER Default
    Default value to return if the key is not found.
    If this is a ScriptBlock, it will be executed and the result will be
    persisted to the .env file using Set-JumpValue.

.PARAMETER Scopes
    List of scopes to set the variable in. Valid values:
    - "Global" - Set as global PowerShell variable
    - "Script" - Set as script-scoped PowerShell variable
    - "Local" - Set as local PowerShell variable
    - "Private" - Set as private PowerShell variable
    - "Env" or "Environment" - Set as environment variable
    Defaults to @("Global", "Env")

.EXAMPLE
    Load-JumpValue -Name "MY_SETTING"
    Gets the value and sets it as $global:MY_SETTING and $env:MY_SETTING

.EXAMPLE
    Load-JumpValue -Name "MY_VALUE" -Scopes @("Global")
    Gets the value and only sets it as $global:MY_VALUE (not as env var)

.EXAMPLE
    Load-JumpValue -Name "COMPUTED_VALUE" -Default { Get-SomeExpensiveValue }
    Executes the scriptblock if not cached, persists the result, sets in default scopes
#>
function Load-JumpValue {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,
        
        [Parameter(Position = 1)]
        $Default,
        
        [Parameter(Position = 2)]
        [ValidateSet("Global", "Script", "Local", "Private", "Env", "Environment")]
        [string[]]$Scopes = @("Global", "Env")
    )
    
    $result = $null
    
    # Search through env files in priority order
    foreach ($envFile in Get-JumpEnvFiles) {
        # Use Read-Dotenv to get values as an OrderedDictionary without setting env vars
        $envVars = Read-Dotenv -Path $envFile
        if ($envVars.Contains($Name)) {
            $result = $envVars[$Name]
            break
        }
    }
    
    # If no result and we have a default
    if ($null -eq $result -and $null -ne $Default) {
        if ($Default -is [ScriptBlock]) {
            # Execute the scriptblock
            $result = & $Default
            # Persist the result
            Set-JumpValue -Name $Name -Value $result
        }
        else {
            # Just return the default value (don't persist)
            $result = $Default
        }
    }
    
    # Set variable in each specified scope
    Set-VariableScopes -Name $Name -Value $result -Scopes $Scopes
    
    return $result
}

<#
.SYNOPSIS
    Sets a value in a per-host .env file

.DESCRIPTION
    Adds or updates a key-value pair in the specified .env file.
    Also sets the variable in the specified scopes.
    If the Value is a ScriptBlock, it will be executed and the result stored.

.PARAMETER Name
    The name of the environment variable

.PARAMETER Value
    The value to set. If this is a ScriptBlock, it will be executed and the result stored.

.PARAMETER Type
    Which .env file to write to:
    - "Secret" - secret.env (for sensitive values, should be in .gitignore)
    - "User" - .env (default, general user settings)
    - "Machine" - <COMPUTERNAME>.env (machine-specific settings)

.PARAMETER Scopes
    List of scopes to set the variable in after writing to file. Valid values:
    - "Global" - Set as global PowerShell variable
    - "Script" - Set as script-scoped PowerShell variable
    - "Local" - Set as local PowerShell variable
    - "Private" - Set as private PowerShell variable
    - "Env" or "Environment" - Set as environment variable
    Defaults to @("Env"). Pass an empty array to not set any variables.

.EXAMPLE
    Set-JumpValue -Name "VSCODE_SHELL_INTEGRATION_PATH" -Value "C:\path\to\script.ps1"
    Adds or updates the value in .env and sets the environment variable

.EXAMPLE
    Set-JumpValue -Name "API_KEY" -Value "secret123" -Type Secret
    Adds the value to secret.env

.EXAMPLE
    Set-JumpValue -Name "COMPUTED" -Value { Get-ExpensiveValue } -Type User
    Executes the scriptblock and stores the result

.EXAMPLE
    Set-JumpValue -Name "MY_VAR" -Value "hello" -Scopes @()
    Stores the value without setting any variables
#>
function Set-JumpValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Name,
        
        [Parameter(Mandatory = $true, Position = 1)]
        $Value,
        
        [Parameter(Position = 2)]
        [ValidateSet("Machine", "User", "Secret")]
        [string]$Type = "User",
        
        [Parameter(Position = 3)]
        [ValidateSet("Global", "Script", "Local", "Private", "Env", "Environment")]
        [string[]]$Scopes = @("Env")
    )
    
    # If Value is a scriptblock, execute it
    if ($Value -is [ScriptBlock]) {
        $Value = & $Value
    }
    
    # Convert to string if needed
    $Value = [string]$Value
    
    # Convert backslashes to forward slashes in paths to avoid dotenv escape issues
    if ($Value -match '^[A-Za-z]:[\\/]') {
        $Value = $Value -replace '\\', '/'
    }
    
    $envFile = Get-JumpEnvFile -Type $Type
    
    # Read existing content, filtering out the key we're adding
    $envContent = @()
    if (Test-Path $envFile) {
        $envContent = @(Get-Content $envFile | Where-Object { $_ -notmatch "^$Name=" })
    }
    
    # Add the new value with proper quoting for values with special characters
    $escapedValue = $Value -replace '"', '\"'
    $envContent += "$Name=`"$escapedValue`""
    
    # Write back to file
    $envContent | Set-Content $envFile -Encoding UTF8
    
    # Set variable in specified scopes
    if ($Scopes -and $Scopes.Count -gt 0) {
        Set-VariableScopes -Name $Name -Value $Value -Scopes $Scopes
    }
}

<#
.SYNOPSIS
    Loads all values from the per-host .env files into specified scopes

.DESCRIPTION
    Reads the per-host .env files and sets all values in the specified scopes.
    Files are loaded in reverse priority order so that higher priority files 
    (secret.env) override lower priority files (<COMPUTERNAME>.env).

.PARAMETER Types
    Optional list of .env file types to load. If not specified, all types are loaded.
    Valid values: "Secret", "User", "Machine"

.PARAMETER Scopes
    List of scopes to set the variables in. Valid values:
    - "Global" - Set as global PowerShell variable
    - "Script" - Set as script-scoped PowerShell variable
    - "Local" - Set as local PowerShell variable
    - "Private" - Set as private PowerShell variable
    - "Env" or "Environment" - Set as environment variable
    Defaults to @("Global", "Env")

.EXAMPLE
    Load-JumpValues
    Loads all cached values into global scope and environment variables

.EXAMPLE
    Load-JumpValues -Types Secret
    Loads only secret.env values

.EXAMPLE
    Load-JumpValues -Scopes @("Env")
    Loads all values only as environment variables
#>
function Load-JumpValues {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet("Machine", "User", "Secret")]
        [string[]]$Types,
        
        [Parameter(Position = 1)]
        [ValidateSet("Global", "Script", "Local", "Private", "Env", "Environment")]
        [string[]]$Scopes = @("Global", "Env")
    )
    
    # Get files, optionally filtered by types
    # Use LowestPriorityFirst so highest priority files are loaded last (override)
    $envFiles = if ($Types) {
        Get-JumpEnvFiles -Types $Types -LowestPriorityFirst
    } else {
        Get-JumpEnvFiles -LowestPriorityFirst
    }
    
    if ($envFiles) {
        foreach ($envFile in $envFiles) {
            # Use Read-Dotenv to get values as a hashtable without setting env vars
            $envVars = Read-Dotenv -Path $envFile
            
            # Set each variable in the specified scopes
            foreach ($entry in $envVars.GetEnumerator()) {
                Set-VariableScopes -Name $entry.Key -Value $entry.Value -Scopes $Scopes
            }
        }
    }
}

function Load-Secrets() {
    Ensure-Module pwsh-dotenv
    Load-JumpValues -Types Secret
}