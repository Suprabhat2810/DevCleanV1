function Invoke-AnalyzeNode {
    <#
    .SYNOPSIS
        Analyzes node_modules directories for activity and safety.
        Reports inactive projects, git status, and restoration instructions.
    #>

    Write-Host ""
    Write-Host "  NODE_MODULES ANALYSIS" -ForegroundColor Yellow
    Write-Host "  ==========================================================" -ForegroundColor DarkGray
    Write-Host ""

    Show-Info "Scanning for node_modules directories..."
    $modules = Scan-NodeModules
    
    if (-not $modules -or $modules.Count -eq 0) {
        Write-Host "  No node_modules directories found." -ForegroundColor Green
        return
    }

    Show-Info "Analyzing $($modules.Count) node_modules directories..."
    Write-Host ""

    $analyzed = @()

    foreach ($m in $modules) {
        $projectDir  = $m.ProjectDir
        $lastMod     = $m.LastModified
        $age         = if ($lastMod) { ((Get-Date) - $lastMod).Days } else { 999 }
        $isGitRepo   = Test-Path (Join-Path $projectDir ".git")
        $hasPkgJson  = Test-Path (Join-Path $projectDir "package.json")
        $hasLockFile = (Test-Path (Join-Path $projectDir "package-lock.json")) -or `
                       (Test-Path (Join-Path $projectDir "yarn.lock")) -or `
                       (Test-Path (Join-Path $projectDir "pnpm-lock.yaml"))

        # Risk classification
        if ($age -gt 180) {
            $risk       = "LOW"
            $riskReason = "Project inactive for $age days"
            $recommendation = "Safe to remove"
        } elseif ($age -gt 60) {
            $risk       = "LOW"
            $riskReason = "Project last used $age days ago"
            $recommendation = "Likely safe to remove"
        } else {
            $risk       = "HIGH"
            $riskReason = "Project recently active ($age days ago)"
            $recommendation = "Keep - project is active"
        }

        $analyzed += [PSCustomObject]@{
            Name           = $m.Name
            Path           = $m.Path
            ProjectDir     = $projectDir
            SizeBytes      = $m.SizeBytes
            RiskLevel      = $risk
            RiskReason     = $riskReason
            Recommendation = $recommendation
            AgeDays        = $age
            IsGitRepo      = $isGitRepo
            HasPackageJson = $hasPkgJson
            HasLockFile    = $hasLockFile
            LastModified   = $lastMod
        }
    }

    # Display results
    foreach ($a in $analyzed | Sort-Object AgeDays -Descending) {
        $riskColor = Get-RiskColor $a.RiskLevel

        Write-Host "  +- " -NoNewline -ForegroundColor DarkGray
        Write-Host $a.Name -ForegroundColor White
        Write-Host "  |  Size:        " -NoNewline -ForegroundColor DarkGray
        Write-Host (Format-FileSize $a.SizeBytes) -ForegroundColor Cyan
        Write-Host "  |  Path:        " -NoNewline -ForegroundColor DarkGray
        Write-Host $a.ProjectDir -ForegroundColor Gray
        Write-Host "  |  Last active: " -NoNewline -ForegroundColor DarkGray
        Write-Host (Format-Age $a.LastModified) -ForegroundColor Gray
        Write-Host "  |  Git repo:    " -NoNewline -ForegroundColor DarkGray
        if ($a.IsGitRepo) { Write-Host "Yes" -ForegroundColor Green } else { Write-Host "No" -ForegroundColor DarkGray }
        Write-Host "  |  package.json:" -NoNewline -ForegroundColor DarkGray
        if ($a.HasPackageJson) { Write-Host " Present" -ForegroundColor Green } else { Write-Host " Missing" -ForegroundColor Red }
        Write-Host "  |  Risk:        " -NoNewline -ForegroundColor DarkGray
        Write-Host "[$($a.RiskLevel)]" -NoNewline -ForegroundColor $riskColor
        Write-Host " - $($a.RiskReason)" -ForegroundColor DarkGray
        Write-Host "  |  Verdict:     " -NoNewline -ForegroundColor DarkGray
        Write-Host $a.Recommendation -ForegroundColor $(if ($a.RiskLevel -eq "HIGH") { "Yellow" } else { "Green" })
        Write-Host "  +------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host ""
    }

    $totalSafe = ($analyzed | Where-Object { $_.RiskLevel -ne "HIGH" } | Measure-Object -Property SizeBytes -Sum).Sum
    $totalAll  = ($analyzed | Measure-Object -Property SizeBytes -Sum).Sum

    Write-Host "  Summary" -ForegroundColor Yellow
    Write-Host "  ---------------------------------" -ForegroundColor DarkGray
    Write-Host "  Total node_modules found: $($analyzed.Count)" -ForegroundColor White
    Write-Host "  Total size:               $(Format-FileSize $totalAll)" -ForegroundColor Cyan
    Write-Host "  Safe to remove:           $(Format-FileSize $totalSafe)" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Restore with:  npm install  |  yarn install  |  pnpm install" -ForegroundColor DarkGray
    Write-Host ""
}

function Get-NodeModuleRisk {
    param([PSCustomObject]$Module)

    $age = if ($Module.LastModified) { ((Get-Date) - $Module.LastModified).Days } else { 999 }

    if ($age -gt 180) { return "LOW" }
    if ($age -gt 60)  { return "LOW" }
    return "HIGH"
}
