function Scan-AndroidSdk {
    <#
    .SYNOPSIS
        Scans Android SDK for reclaimable storage.
        Reads ANDROID_HOME / ANDROID_SDK_ROOT env vars and common default paths.
    #>

    $sdkRoot = $env:ANDROID_HOME
    if (-not $sdkRoot) { $sdkRoot = $env:ANDROID_SDK_ROOT }
    if (-not $sdkRoot) { $sdkRoot = Join-Path $env:LOCALAPPDATA "Android\Sdk" }

    $results = @()

    if (-not (Test-Path $sdkRoot)) { return $results }

    # -- 1. System Images (largest, often multiple versions) -------------------
    $sysImgRoot = Join-Path $sdkRoot "system-images"
    if (Test-Path $sysImgRoot) {
        foreach ($apiDir in Get-ChildItem $sysImgRoot -Directory -ErrorAction SilentlyContinue) {
            foreach ($imgDir in Get-ChildItem $apiDir.FullName -Directory -ErrorAction SilentlyContinue) {
                foreach ($abiDir in Get-ChildItem $imgDir.FullName -Directory -ErrorAction SilentlyContinue) {
                    $size = Get-FolderSize -Path $abiDir.FullName
                    if ($size -gt 100MB) {
                        $results += [PSCustomObject]@{
                            Name       = "System Image $($apiDir.Name) [$($imgDir.Name)/$($abiDir.Name)]"
                            Path       = $abiDir.FullName
                            SizeBytes  = $size
                            RiskLevel  = "MEDIUM"
                            RiskReason = "Emulator image. Safe if you don't use this AVD config."
                            Category   = "sdk"
                            Scanner    = "sdk"
                            SubType    = "system-image"
                        }
                    }
                }
            }
        }
    }

    # -- 2. Old NDK versions ---------------------------------------------------
    $ndkRoot = Join-Path $sdkRoot "ndk"
    if (Test-Path $ndkRoot) {
        foreach ($ndkVer in Get-ChildItem $ndkRoot -Directory -ErrorAction SilentlyContinue) {
            $size = Get-FolderSize -Path $ndkVer.FullName
            $results += [PSCustomObject]@{
                Name       = "NDK $($ndkVer.Name)"
                Path       = $ndkVer.FullName
                SizeBytes  = $size
                RiskLevel  = "MEDIUM"
                RiskReason = "NDK version - check if referenced by active projects before removing."
                Category   = "sdk"
                Scanner    = "sdk"
                SubType    = "ndk"
                Version    = $ndkVer.Name
            }
        }
    }

    # -- 3. Temp / build-cache inside SDK -------------------------------------
    $tempPaths = @(
        @{ Sub = "temp";           Label = "SDK Temp Files";     Risk = "SAFE" }
        @{ Sub = "build-tools\staging"; Label = "Build Tools Staging"; Risk = "SAFE" }
    )

    foreach ($t in $tempPaths) {
        $fullPath = Join-Path $sdkRoot $t.Sub
        if (Test-Path $fullPath) {
            $size = Get-FolderSize -Path $fullPath
            if ($size -gt 0) {
                $results += [PSCustomObject]@{
                    Name       = $t.Label
                    Path       = $fullPath
                    SizeBytes  = $size
                    RiskLevel  = $t.Risk
                    RiskReason = "Temporary SDK files. Safe to remove."
                    Category   = "sdk"
                    Scanner    = "sdk"
                    SubType    = "temp"
                }
            }
        }
    }

    return $results
}
