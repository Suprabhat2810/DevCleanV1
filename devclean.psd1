@{
    ModuleVersion     = '1.0.0'
    GUID              = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    Author            = 'Suprabhat Chowhan'
    Description       = 'DevClean — Developer Workstation Cleanup CLI'
    PowerShellVersion = '7.0'
    RootModule        = 'devclean.ps1'

    FunctionsToExport = @(
        'Invoke-Scan',
        'Invoke-CleanupAll',
        'Invoke-CleanupTarget',
        'Invoke-AnalyzeSdk',
        'Invoke-AnalyzeNode',
        'Invoke-Undo'
    )

    PrivateData = @{
        PSData = @{
            Tags       = @('developer', 'cleanup', 'android', 'node', 'gradle', 'windows')
            ProjectUri = 'https://github.com/suprabhat/devclean'
        }
    }
}
