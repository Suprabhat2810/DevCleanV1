function Invoke-AnalyzeSdk {
    <#
    .SYNOPSIS
        Analyzes Android SDK/NDK usage by scanning build.gradle files.
        Identifies which NDK versions are actively referenced vs orphaned.
    #>

    Write-Host ""
    Write-Host "  ANDROID SDK DEPENDENCY ANALYSIS" -ForegroundColor Yellow
    Write-Host "  ==========================================================" -ForegroundColor DarkGray
    Write-Host ""

    # -- 1. Find SDK root -----------------------------------------------------
    $sdkRoot = $env:ANDROID_HOME
    if (-not $sdkRoot) { $sdkRoot = $env:ANDROID_SDK_ROOT }
    if (-not $sdkRoot) { $sdkRoot = Join-Path $env:LOCALAPPDATA "Android\Sdk" }

    if (-not (Test-Path $sdkRoot)) {
        Show-Warning "Android SDK not found. Set ANDROID_HOME environment variable."
        return
    }

    Show-Info "SDK Root: $sdkRoot"

    # -- 2. Get installed NDK versions ----------------------------------------
    $ndkRoot       = Join-Path $sdkRoot "ndk"
    $installedNdks = @()

    if (Test-Path $ndkRoot) {
        $installedNdks = (Get-ChildItem $ndkRoot -Directory -ErrorAction SilentlyContinue).Name
        Show-Info "Installed NDK versions: $($installedNdks -join ', ')"
    } else {
        Show-Info "No NDK versions installed."
    }

    # -- 3. Scan build.gradle / build.gradle.kts files ------------------------
    Write-Host ""
    Show-Info "Scanning build.gradle files for NDK references..."

    $searchRoots = @(
        $env:USERPROFILE,
        "C:\dev", "C:\projects", "C:\repos", "C:\src", "C:\workspace",
        (Join-Path $env:USERPROFILE "AndroidStudioProjects")
    )

    $referencedNdks    = [System.Collections.Generic.HashSet[string]]::new()
    $referencedSdks    = [System.Collections.Generic.HashSet[string]]::new()
    $gradleFilesFound  = 0
    $projectsFound     = @()

    foreach ($root in $searchRoots) {
        if (-not (Test-Path $root)) { continue }

        try {
            # PS5.1 compatible - use Get-ChildItem instead of EnumerationOptions
            $gradleFiles = Get-ChildItem -Path $root -Filter "build.gradle" -Recurse `
                               -ErrorAction SilentlyContinue -Force |
                           Select-Object -First 500

            foreach ($gradleFileInfo in $gradleFiles) {
                $gradleFile = $gradleFileInfo.FullName
                $gradleFilesFound++
                $content = Get-Content $gradleFile -Raw -ErrorAction SilentlyContinue
                if (-not $content) { continue }

                # Parse ndkVersion
                $ndkMatches = [regex]::Matches($content, 'ndkVersion\s+["\x27]?([\d.]+)["\x27]?')
                foreach ($match in $ndkMatches) {
                    $ver = $match.Groups[1].Value.Trim()
                    [void]$referencedNdks.Add($ver)
                    $projectsFound += [PSCustomObject]@{
                        GradleFile = $gradleFile
                        Type       = "ndkVersion"
                        Value      = $ver
                    }
                }

                # Parse compileSdk / targetSdk / minSdk
                foreach ($prop in @("compileSdk","targetSdk","minSdk","compileSdkVersion","targetSdkVersion","minSdkVersion")) {
                    $sdkMatches = [regex]::Matches($content, "$prop\s+(\d+)")
                    foreach ($m in $sdkMatches) {
                        [void]$referencedSdks.Add($m.Groups[1].Value)
                    }
                }
            }

            # Also scan .kts files
            $ktsFiles = Get-ChildItem -Path $root -Filter "build.gradle.kts" -Recurse `
                            -ErrorAction SilentlyContinue -Force |
                        Select-Object -First 200

            foreach ($ktsFileInfo in $ktsFiles) {
                $gradleFilesFound++
                $content = Get-Content $ktsFileInfo.FullName -Raw -ErrorAction SilentlyContinue
                if (-not $content) { continue }

                $ndkMatches = [regex]::Matches($content, 'ndkVersion\s*=\s*["\x27]([\d.]+)["\x27]')
                foreach ($match in $ndkMatches) {
                    $ver = $match.Groups[1].Value.Trim()
                    [void]$referencedNdks.Add($ver)
                }
            }
        } catch { <# skip inaccessible #> }
    }

    Write-Host ""
    Write-Host "  PROJECT SCAN RESULTS" -ForegroundColor Yellow
    Write-Host "  ---------------------------------------------" -ForegroundColor DarkGray
    Write-Host "  build.gradle files scanned: $gradleFilesFound" -ForegroundColor Gray
    Write-Host "  NDK versions referenced:    $($referencedNdks.Count)" -ForegroundColor Gray
    if ($referencedSdks.Count -gt 0) {
        Write-Host "  SDK API levels referenced:  $($referencedSdks -join ', ')" -ForegroundColor Gray
    }
    Write-Host ""

    # -- 4. Cross-reference installed vs referenced ----------------------------
    if ($installedNdks.Count -gt 0) {
        Write-Host "  NDK ANALYSIS" -ForegroundColor Yellow
        Write-Host "  ---------------------------------------------" -ForegroundColor DarkGray

        foreach ($ndk in $installedNdks) {
            $isReferenced = $false

            foreach ($ref in $referencedNdks) {
                if ($ndk -like "$ref*" -or $ref -like "$ndk*") {
                    $isReferenced = $true
                    break
                }
            }

            $ndkPath = Join-Path $ndkRoot $ndk
            $ndkSize = Get-FolderSize -Path $ndkPath

            if ($isReferenced) {
                Write-Host "  [OK]  NDK $ndk" -NoNewline -ForegroundColor Green
                Write-Host " - $(Format-FileSize $ndkSize)" -NoNewline -ForegroundColor Gray
                Write-Host " - Referenced by active projects. Keep." -ForegroundColor DarkGray
            } else {
                Write-Host "  [WARN]  NDK $ndk" -NoNewline -ForegroundColor Yellow
                Write-Host " - $(Format-FileSize $ndkSize)" -NoNewline -ForegroundColor Gray
                Write-Host " - Not referenced. Safe to remove." -ForegroundColor DarkGray
            }
        }
        Write-Host ""
    }

    # -- 5. Show project references --------------------------------------------
    if ($projectsFound.Count -gt 0) {
        Write-Host "  ACTIVE NDK REFERENCES FOUND" -ForegroundColor Yellow
        Write-Host "  ---------------------------------------------" -ForegroundColor DarkGray
        foreach ($p in $projectsFound | Select-Object -First 10) {
            $shortPath = $p.GradleFile -replace [regex]::Escape($env:USERPROFILE), "~"
            Write-Host "  NDK $($p.Value.PadRight(12))" -NoNewline -ForegroundColor Cyan
            Write-Host $shortPath -ForegroundColor DarkGray
        }
        if ($projectsFound.Count -gt 10) {
            Write-Host "  ... and $($projectsFound.Count - 10) more" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "  No active NDK references found in scanned projects." -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "  To remove unused NDKs: devclean cleanup sdk --interactive" -ForegroundColor Cyan
    Write-Host ""
}
