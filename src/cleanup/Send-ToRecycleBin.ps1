function Send-ToRecycleBin {
    <#
    .SYNOPSIS
        Moves a file or folder to the Windows Recycle Bin using Shell32 COM API.
        Falls back to Microsoft.VisualBasic if Shell32 fails.
    #>
    param(
        [string]$Path,
        [switch]$Permanent
    )

    if (-not (Test-Path $Path)) {
        Write-Verbose "Path not found, skipping: $Path"
        return $false
    }

    if ($Permanent) {
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            return $true
        } catch {
            Write-Verbose "Permanent delete failed: $_"
            return $false
        }
    }

    # -- Try Microsoft.VisualBasic (most reliable) -----------------------------
    try {
        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction SilentlyContinue

        $isDir = (Get-Item $Path -ErrorAction SilentlyContinue) -is [System.IO.DirectoryInfo]

        if ($isDir) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                $Path,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
            )
        } else {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                $Path,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
            )
        }
        return $true
    } catch {
        Write-Verbose "VB recycle bin failed: $_ - trying Shell32"
    }

    # -- Fallback: Shell32 COM -------------------------------------------------
    try {
        $shell  = New-Object -ComObject Shell.Application
        $parent = Split-Path $Path -Parent
        $leaf   = Split-Path $Path -Leaf
        $folder = $shell.Namespace($parent)
        $item   = $folder.ParseName($leaf)

        if ($item) {
            $item.InvokeVerb("delete")
            return $true
        }
    } catch {
        Write-Verbose "Shell32 recycle bin failed: $_"
    }

    # -- Last resort: hard delete with warning ----------------------------------
    try {
        Show-Warning "Recycle Bin not available for: $Path - using permanent delete."
        Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
        return $true
    } catch {
        Show-Error "Failed to delete: $Path`n  $_"
        return $false
    }
}

function Remove-FileSafely {
    <#
    .SYNOPSIS
        Removes a single file safely, skipping locked files.
    #>
    param([string]$Path, [switch]$Permanent)

    try {
        if ($Permanent) {
            Remove-Item -Path $Path -Force -ErrorAction Stop
        } else {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                $Path,
                [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin
            )
        }
        return $true
    } catch {
        Write-Verbose "Skipping locked file: $Path"
        return $false
    }
}
