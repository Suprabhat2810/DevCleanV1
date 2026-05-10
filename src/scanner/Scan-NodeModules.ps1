function Scan-NodeModules {
    <#
    .SYNOPSIS
        Recursively finds node_modules directories across common dev locations.
        Skips node_modules nested inside other node_modules.
    #>
    param(
        [string[]]$SearchRoots = @(
            $env:USERPROFILE,
            "C:\dev",
            "C:\projects",
            "C:\repos",
            "C:\src",
            "C:\workspace"
        )
    )

    $results = @()
    $seen    = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($root in $SearchRoots) {
        if (-not (Test-Path $root)) { continue }

        try {
            $opts = [System.IO.EnumerationOptions]::new()
            $opts.RecurseSubdirectories = $true
            $opts.IgnoreInaccessible    = $true
            $opts.MaxRecursionDepth     = 8

            foreach ($dir in [System.IO.Directory]::EnumerateDirectories($root, "node_modules", $opts)) {

                # Skip nested node_modules (node_modules inside node_modules)
                $parent = Split-Path $dir -Parent
                if ($parent -match "node_modules") { continue }

                # Deduplicate
                if (-not $seen.Add($dir)) { continue }

                $size    = Get-FolderSize -Path $dir
                $project = Split-Path $parent -Leaf
                $lastMod = (Get-Item $parent -ErrorAction SilentlyContinue)?.LastWriteTime

                $results += [PSCustomObject]@{
                    Name       = "node_modules ($project)"
                    Path       = $dir
                    SizeBytes  = $size
                    RiskLevel  = "LOW"
                    RiskReason = "Source code and package.json are untouched. Run npm install to restore."
                    Category   = "node"
                    Scanner    = "node"
                    ProjectDir = $parent
                    LastModified = $lastMod
                }
            }
        } catch { <# skip inaccessible roots #> }
    }

    return $results
}
