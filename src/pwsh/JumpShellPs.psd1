@{
    # Script module or binary module file associated with this manifest
    RootModule        = 'JumpShellPs.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = 'b1e7e2e2-1c2a-4e2a-9b2e-123456789abc'
    Author            = 'Your Name'
    Description       = 'JumpShell PowerShell 7 Module'
    PowerShellVersion = '7.0'
    FunctionsToExport = '*'
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = '*'
    PrivateData       = @{}
    RequiredModules   = @(
        'PowerHTML',
        'HomeAssistantPs',
        'pwsh-dotenv',
        'Microsoft.PowerShell.SecretManagement',
#        'Microsoft.PowerShell.CredManStore',
        "CredMan",
        'Pscx'
    )
}
