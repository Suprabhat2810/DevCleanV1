function Get-FolderSize {
    param(
        [string]$Path,
        [switch]$IncludeHidden
    )

    if (-not (Test-Path $Path)) { return 0L }

    try {
        $totalSize = 0L
        Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer } |
            ForEach-Object {
                try { $totalSize += $_.Length } catch {}
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
        return (Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue |
            Where-Object { -not $_.PSIsContainer }).Count
    } catch { return 0 }
}

function Get-SubFolderSizes {
    param([string]$Path)
    $results = @()
    if (-not (Test-Path $Path)) { return $results }
    foreach ($dir in Get-ChildItem -Path $Path -Directory -ErrorAction SilentlyContinue) {
        $size = Get-FolderSize -Path $dir.FullName
        $results += [PSCustomObject]@{
            Path      = $dir.FullName
            Name      = $dir.Name
            SizeBytes = $size
        }
    }
    return $results | Sort-Object SizeBytes -Descending
}
