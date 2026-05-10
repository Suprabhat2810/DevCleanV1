function Get-FolderSize {
    <#
    .SYNOPSIS
        Fast folder size calculation using .NET enumeration.
        Significantly faster than Get-ChildItem -Recurse for large trees.
    #>
    param(
        [string]$Path,
        [switch]$IncludeHidden
    )

    if (-not (Test-Path $Path)) { return 0 }

    try {
        $totalSize = 0L
        $opts = [System.IO.EnumerationOptions]::new()
        $opts.RecurseSubdirectories = $true
        $opts.IgnoreInaccessible    = $true
        $opts.AttributesToSkip      = if ($IncludeHidden) { [System.IO.FileAttributes]::None } `
                                      else { [System.IO.FileAttributes]::System }

        foreach ($file in [System.IO.Directory]::EnumerateFiles($Path, "*", $opts)) {
            try {
                $totalSize += (New-Object System.IO.FileInfo($file)).Length
            } catch { <# skip locked files #> }
        }

        return $totalSize
    } catch {
        return 0L
    }
}

function Get-FolderItemCount {
    param([string]$Path)

    if (-not (Test-Path $Path)) { return 0 }

    try {
        $opts = [System.IO.EnumerationOptions]::new()
        $opts.RecurseSubdirectories = $true
        $opts.IgnoreInaccessible    = $true

        return ([System.IO.Directory]::EnumerateFiles($Path, "*", $opts) | Measure-Object).Count
    } catch {
        return 0
    }
}

function Get-SubFolderSizes {
    <#
    .SYNOPSIS
        Returns a list of immediate subfolders with their sizes.
        Used by analyzers to find the largest children.
    #>
    param([string]$Path)

    $results = @()

    if (-not (Test-Path $Path)) { return $results }

    foreach ($dir in [System.IO.Directory]::GetDirectories($Path)) {
        $size = Get-FolderSize -Path $dir
        $results += [PSCustomObject]@{
            Path      = $dir
            Name      = Split-Path $dir -Leaf
            SizeBytes = $size
        }
    }

    return $results | Sort-Object SizeBytes -Descending
}
