function Scan-Browsers {
    <#
    .SYNOPSIS
        Scans cache directories for ALL major browsers installed on the system.
        Detects: Chrome, Edge, Brave, Firefox, Opera, Vivaldi, Arc, Waterfox,
                 LibreWolf, Thorium, Chromium, Samsung Internet, Yandex, Zen.
        Only scans browsers that are actually installed — skips missing ones.
    #>

    # ── Browser profile definitions ───────────────────────────────────────────
    # Each entry: Name, BasePath (relative to $env:LOCALAPPDATA or $env:APPDATA),
    #             ProfileFolder, CacheFolders[], BaseRoot
    $browsers = @(

        # ── Chromium-family ───────────────────────────────────────────────────
        @{
            Name          = "Google Chrome"
            BaseRoot      = "LOCAL"
            BasePath      = "Google\Chrome\User Data"
            ProfileGlob   = @("Default", "Profile *")
            CacheFolders  = @("Cache","Cache2\entries","GPUCache","Code Cache","DawnCache","ShaderCache","Media Cache","Service Worker\CacheStorage","Service Worker\ScriptCache")
            Risk          = "SAFE"
            RiskReason    = "Chrome cache rebuilds automatically. No passwords or bookmarks affected."
            Category      = "browser"
        }
        @{
            Name          = "Microsoft Edge"
            BaseRoot      = "LOCAL"
            BasePath      = "Microsoft\Edge\User Data"
            ProfileGlob   = @("Default", "Profile *")
            CacheFolders  = @("Cache","Cache2\entries","GPUCache","Code Cache","DawnCache","ShaderCache","Media Cache","Service Worker\CacheStorage")
            Risk          = "SAFE"
            RiskReason    = "Edge cache rebuilds automatically. No passwords, bookmarks, or extensions affected."
            Category      = "browser"
        }
        @{
            Name          = "Brave Browser"
            BaseRoot      = "LOCAL"
            BasePath      = "BraveSoftware\Brave-Browser\User Data"
            ProfileGlob   = @("Default", "Profile *")
            CacheFolders  = @("Cache","Cache2\entries","GPUCache","Code Cache","DawnCache","ShaderCache","Media Cache","Service Worker\CacheStorage")
            Risk          = "SAFE"
            RiskReason    = "Brave cache rebuilds automatically. Brave Rewards wallet data is stored separately and is NOT affected."
            Category      = "browser"
        }
        @{
            Name          = "Opera"
            BaseRoot      = "APPDATA"
            BasePath      = "Opera Software\Opera Stable"
            ProfileGlob   = @(".")
            CacheFolders  = @("Cache","GPUCache","Code Cache","ShaderCache")
            Risk          = "SAFE"
            RiskReason    = "Opera cache rebuilds automatically."
            Category      = "browser"
        }
        @{
            Name          = "Opera GX"
            BaseRoot      = "APPDATA"
            BasePath      = "Opera Software\Opera GX Stable"
            ProfileGlob   = @(".")
            CacheFolders  = @("Cache","GPUCache","Code Cache","ShaderCache")
            Risk          = "SAFE"
            RiskReason    = "Opera GX cache rebuilds automatically."
            Category      = "browser"
        }
        @{
            Name          = "Vivaldi"
            BaseRoot      = "LOCAL"
            BasePath      = "Vivaldi\User Data"
            ProfileGlob   = @("Default", "Profile *")
            CacheFolders  = @("Cache","Cache2\entries","GPUCache","Code Cache","ShaderCache")
            Risk          = "SAFE"
            RiskReason    = "Vivaldi cache rebuilds automatically."
            Category      = "browser"
        }
        @{
            Name          = "Chromium"
            BaseRoot      = "LOCAL"
            BasePath      = "Chromium\User Data"
            ProfileGlob   = @("Default", "Profile *")
            CacheFolders  = @("Cache","Cache2\entries","GPUCache","Code Cache","ShaderCache")
            Risk          = "SAFE"
            RiskReason    = "Chromium cache rebuilds automatically."
            Category      = "browser"
        }
        @{
            Name          = "Thorium"
            BaseRoot      = "LOCAL"
            BasePath      = "Thorium\User Data"
            ProfileGlob   = @("Default", "Profile *")
            CacheFolders  = @("Cache","Cache2\entries","GPUCache","Code Cache")
            Risk          = "SAFE"
            RiskReason    = "Thorium cache rebuilds automatically."
            Category      = "browser"
        }
        @{
            Name          = "Yandex Browser"
            BaseRoot      = "LOCAL"
            BasePath      = "Yandex\YandexBrowser\User Data"
            ProfileGlob   = @("Default", "Profile *")
            CacheFolders  = @("Cache","GPUCache","Code Cache")
            Risk          = "SAFE"
            RiskReason    = "Yandex Browser cache rebuilds automatically."
            Category      = "browser"
        }
        @{
            Name          = "Samsung Internet"
            BaseRoot      = "LOCAL"
            BasePath      = "Samsung\SamsungBrowser\User Data"
            ProfileGlob   = @("Default")
            CacheFolders  = @("Cache","GPUCache")
            Risk          = "SAFE"
            RiskReason    = "Samsung Internet cache rebuilds automatically."
            Category      = "browser"
        }
        @{
            Name          = "Arc Browser"
            BaseRoot      = "LOCAL"
            BasePath      = "Arc\User Data"
            ProfileGlob   = @("Default", "Profile *")
            CacheFolders  = @("Cache","Cache2\entries","GPUCache","Code Cache")
            Risk          = "SAFE"
            RiskReason    = "Arc cache rebuilds automatically."
            Category      = "browser"
        }
        @{
            Name          = "Cốc Cốc"
            BaseRoot      = "LOCAL"
            BasePath      = "CocCoc\Browser\User Data"
            ProfileGlob   = @("Default")
            CacheFolders  = @("Cache","GPUCache","Code Cache")
            Risk          = "SAFE"
            RiskReason    = "Cốc Cốc cache rebuilds automatically."
            Category      = "browser"
        }

        # ── Firefox-family ────────────────────────────────────────────────────
        @{
            Name          = "Mozilla Firefox"
            BaseRoot      = "APPDATA"
            BasePath      = "Mozilla\Firefox\Profiles"
            ProfileGlob   = @("*")          # all profile folders
            CacheFolders  = @("cache2\entries","startupCache","thumbnails","OfflineCache")
            Risk          = "SAFE"
            RiskReason    = "Firefox cache rebuilds on next launch. Bookmarks, passwords, and extensions are stored separately."
            Category      = "browser"
            IsFirefox     = $true
        }
        @{
            Name          = "LibreWolf"
            BaseRoot      = "APPDATA"
            BasePath      = "librewolf\Profiles"
            ProfileGlob   = @("*")
            CacheFolders  = @("cache2\entries","startupCache","thumbnails")
            Risk          = "SAFE"
            RiskReason    = "LibreWolf cache rebuilds on next launch."
            Category      = "browser"
            IsFirefox     = $true
        }
        @{
            Name          = "Waterfox"
            BaseRoot      = "APPDATA"
            BasePath      = "Waterfox\Profiles"
            ProfileGlob   = @("*")
            CacheFolders  = @("cache2\entries","startupCache","thumbnails")
            Risk          = "SAFE"
            RiskReason    = "Waterfox cache rebuilds on next launch."
            Category      = "browser"
            IsFirefox     = $true
        }
        @{
            Name          = "Zen Browser"
            BaseRoot      = "APPDATA"
            BasePath      = "zen\Profiles"
            ProfileGlob   = @("*")
            CacheFolders  = @("cache2\entries","startupCache")
            Risk          = "SAFE"
            RiskReason    = "Zen Browser cache rebuilds on next launch."
            Category      = "browser"
            IsFirefox     = $true
        }
        @{
            Name          = "Pale Moon"
            BaseRoot      = "APPDATA"
            BasePath      = "Moonchild Productions\Pale Moon\Profiles"
            ProfileGlob   = @("*")
            CacheFolders  = @("cache2\entries","thumbnails")
            Risk          = "SAFE"
            RiskReason    = "Pale Moon cache rebuilds on next launch."
            Category      = "browser"
            IsFirefox     = $true
        }

        # ── Standalone caches ─────────────────────────────────────────────────
        @{
            Name          = "Internet Explorer"
            BaseRoot      = "LOCAL"
            BasePath      = "Microsoft\Windows\INetCache"
            ProfileGlob   = @(".")
            CacheFolders  = @("IE","Low\IE","Content.IE5")
            Risk          = "SAFE"
            RiskReason    = "Legacy IE cache. Safe to remove."
            Category      = "browser"
        }
    )

    # ── Resolution helpers ────────────────────────────────────────────────────
    $results = @()
    $seen    = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($browser in $browsers) {

        $baseEnv  = if ($browser.BaseRoot -eq "LOCAL") { $env:LOCALAPPDATA } else { $env:APPDATA }
        $basePath = Join-Path $baseEnv $browser.BasePath

        # Resolve profile folders
        $profileDirs = @()

        if ($browser.ProfileGlob -contains ".") {
            # Flat layout (Opera, IE) — base path IS the profile
            if (Test-Path $basePath) { $profileDirs += $basePath }
        } elseif ($browser.ContainsKey("IsFirefox") -and $browser.IsFirefox) {
            # Firefox profiles are named like "abc12345.default-release"
            if (Test-Path $basePath) {
                $profileDirs += (Get-ChildItem $basePath -Directory -ErrorAction SilentlyContinue).FullName
            }
        } else {
            # Chromium multi-profile layout
            if (-not (Test-Path $basePath)) { continue }

            foreach ($glob in $browser.ProfileGlob) {
                $profileDirs += (Get-ChildItem $basePath -Directory -Filter $glob -ErrorAction SilentlyContinue).FullName
            }
        }

        if ($profileDirs.Count -eq 0) { continue }

        # Accumulate size across all profiles and cache dirs
        $totalSize     = 0L
        $foundPaths    = @()

        foreach ($profileDir in $profileDirs) {
            foreach ($cacheFolder in $browser.CacheFolders) {
                $cachePath = Join-Path $profileDir $cacheFolder
                if (-not (Test-Path $cachePath)) { continue }
                if (-not $seen.Add($cachePath))   { continue }  # deduplicate

                $size = Get-FolderSize -Path $cachePath
                if ($size -gt 0) {
                    $totalSize  += $size
                    $foundPaths += $cachePath
                }
            }
        }

        if ($totalSize -gt 0) {
            # Determine profile label
            $profileLabel = if ($profileDirs.Count -gt 1) { " ($($profileDirs.Count) profiles)" } else { "" }

            $results += [PSCustomObject]@{
                Name       = "$($browser.Name)$profileLabel Cache"
                Path       = $basePath       # top-level path shown in scan table
                Paths      = $foundPaths     # all individual cache paths for deletion
                SizeBytes  = $totalSize
                RiskLevel  = $browser.Risk
                RiskReason = $browser.RiskReason
                Category   = "browser"
                Scanner    = "browser"
                BrowserName = $browser.Name
            }
        }
    }

    return $results
}

# ── Keep Scan-Chrome as a thin wrapper for backwards compatibility ─────────────
function Scan-Chrome {
    return Scan-Browsers | Where-Object { $_.BrowserName -eq "Google Chrome" }
}

function Get-InstalledBrowsers {
    <#
    .SYNOPSIS
        Returns a simple list of browser names that were detected on this system.
    #>
    $detected = Scan-Browsers
    return $detected | Select-Object -ExpandProperty BrowserName
}
