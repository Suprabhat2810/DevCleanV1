function Show-EducationalNote {
    param([string]$Target)

    Write-Host ""
    switch ($Target.ToLower()) {

        { $_ -eq "chrome" -or $_ -eq "browser" } {
            Write-Host "  +- What is Browser Cache? --------------------------------+" -ForegroundColor DarkGray
            Write-Host "  |" -ForegroundColor DarkGray
            Write-Host "  |  Browsers store cached web pages, images, scripts,     " -ForegroundColor Gray
            Write-Host "  |  GPU shaders, and service workers on disk to speed up  " -ForegroundColor Gray
            Write-Host "  |  browsing. This applies to ALL detected browsers:      " -ForegroundColor Gray
            Write-Host "  |                                                          " -ForegroundColor Gray
            Write-Host "  |  * Chrome  * Edge  * Brave  * Firefox  * Opera         " -ForegroundColor Cyan
            Write-Host "  |  * Vivaldi  * LibreWolf  * Waterfox  * Arc  * Zen      " -ForegroundColor Cyan
            Write-Host "  |                                                          " -ForegroundColor Gray
            Write-Host "  |  These files are SAFE to remove.                        " -ForegroundColor Gray
            Write-Host "  |  Browsers rebuild cache automatically as you browse.   " -ForegroundColor Gray
            Write-Host "  |                                                          " -ForegroundColor Gray
            Write-Host "  |  What is NOT touched:                                   " -ForegroundColor Gray
            Write-Host "  |  · Passwords / saved logins                            " -ForegroundColor Green
            Write-Host "  |  · Bookmarks and history                               " -ForegroundColor Green
            Write-Host "  |  · Extensions and settings                             " -ForegroundColor Green
            Write-Host "  |  · Brave Rewards wallet                                " -ForegroundColor Green
            Write-Host "  |                                                          " -ForegroundColor Gray
            Write-Host "  |  Temporary impact:                                       " -ForegroundColor Gray
            Write-Host "  |  · Pages may load slightly slower for 10-30 minutes    " -ForegroundColor DarkGray
            Write-Host "  |  · No re-login required                                " -ForegroundColor DarkGray
            Write-Host "  +-----------------------------------------------------------+" -ForegroundColor DarkGray
        }

        "gradle" {
            Write-Host "  +- What is the Gradle Cache? -----------------------------+" -ForegroundColor DarkGray
            Write-Host "  |" -ForegroundColor DarkGray
            Write-Host "  |  The Gradle cache stores downloaded dependencies,       " -ForegroundColor Gray
            Write-Host "  |  build artifacts, and daemon PID files for Android      " -ForegroundColor Gray
            Write-Host "  |  and Java projects.                                     " -ForegroundColor Gray
            Write-Host "  |                                                          " -ForegroundColor Gray
            Write-Host "  |  These files are SAFE to remove.                        " -ForegroundColor Gray
            Write-Host "  |  Gradle will re-download only what it needs on next     " -ForegroundColor Gray
            Write-Host "  |  build.                                                  " -ForegroundColor Gray
            Write-Host "  |                                                          " -ForegroundColor Gray
            Write-Host "  |  Temporary impact:                                       " -ForegroundColor Gray
            Write-Host "  |  · First build after cleanup will be slower             " -ForegroundColor DarkGray
            Write-Host "  |  · Dependencies will re-download from Maven Central     " -ForegroundColor DarkGray
            Write-Host "  |                                                          " -ForegroundColor Gray
            Write-Host "  |  Restoration: Run 'gradle build' in your project.       " -ForegroundColor DarkGray
            Write-Host "  +-----------------------------------------------------------+" -ForegroundColor DarkGray
        }

        "node" {
            Write-Host "  +- What are node_modules? --------------------------------+" -ForegroundColor DarkGray
            Write-Host "  |" -ForegroundColor DarkGray
            Write-Host "  |  node_modules contains installed npm/yarn/pnpm           " -ForegroundColor Gray
            Write-Host "  |  dependencies for JavaScript/Node.js projects.           " -ForegroundColor Gray
            Write-Host "  |                                                           " -ForegroundColor Gray
            Write-Host "  |  Removing node_modules does NOT remove:                  " -ForegroundColor Gray
            Write-Host "  |  · Your source code                                      " -ForegroundColor Green
            Write-Host "  |  · package.json or package-lock.json                     " -ForegroundColor Green
            Write-Host "  |  · Project configuration files                           " -ForegroundColor Green
            Write-Host "  |                                                           " -ForegroundColor Gray
            Write-Host "  |  Restoration:  npm install  (or yarn / pnpm install)     " -ForegroundColor Cyan
            Write-Host "  |                                                           " -ForegroundColor Gray
            Write-Host "  |  Temporary impact:                                        " -ForegroundColor Gray
            Write-Host "  |  · Re-install required before next build                 " -ForegroundColor DarkGray
            Write-Host "  +-----------------------------------------------------------+" -ForegroundColor DarkGray
        }

        "sdk" {
            Write-Host "  +- What are Android SDK temp files? ----------------------+" -ForegroundColor DarkGray
            Write-Host "  |" -ForegroundColor DarkGray
            Write-Host "  |  The Android SDK accumulates old NDK versions, unused   " -ForegroundColor Gray
            Write-Host "  |  platform images, and duplicate build tools over time.  " -ForegroundColor Gray
            Write-Host "  |                                                          " -ForegroundColor Gray
            Write-Host "  |  DevClean scans your build.gradle files FIRST to        " -ForegroundColor Yellow
            Write-Host "  |  detect which NDK/SDK versions are actively used.       " -ForegroundColor Yellow
            Write-Host "  |                                                          " -ForegroundColor Gray
            Write-Host "  |  Only UNREFERENCED versions are flagged for removal.    " -ForegroundColor Gray
            Write-Host "  |                                                          " -ForegroundColor Gray
            Write-Host "  |  Restoration: Re-install via Android Studio SDK Manager " -ForegroundColor DarkGray
            Write-Host "  |  or 'sdkmanager' CLI.                                   " -ForegroundColor DarkGray
            Write-Host "  +-----------------------------------------------------------+" -ForegroundColor DarkGray
        }

        "temp" {
            Write-Host "  +- What are Windows Temp Files? --------------------------+" -ForegroundColor DarkGray
            Write-Host "  |" -ForegroundColor DarkGray
            Write-Host "  |  Windows and applications store temporary files in:     " -ForegroundColor Gray
            Write-Host "  |  · %TEMP% (user-level)                                  " -ForegroundColor Gray
            Write-Host "  |  · C:\Windows\Temp (system-level)                       " -ForegroundColor Gray
            Write-Host "  |                                                          " -ForegroundColor Gray
            Write-Host "  |  These files accumulate from installers, crashes, and   " -ForegroundColor Gray
            Write-Host "  |  system operations. They are safe to remove.            " -ForegroundColor Gray
            Write-Host "  |                                                          " -ForegroundColor Gray
            Write-Host "  |  Some files may be locked by running processes and      " -ForegroundColor DarkGray
            Write-Host "  |  will be skipped automatically.                         " -ForegroundColor DarkGray
            Write-Host "  |                                                          " -ForegroundColor Gray
            Write-Host "  |  Restoration: Not required.                             " -ForegroundColor DarkGray
            Write-Host "  +-----------------------------------------------------------+" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
}
