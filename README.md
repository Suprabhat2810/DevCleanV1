# DevClean

> Developer-aware workstation cleanup CLI for Windows

```
╔════════════════════════════════════════╗
║              DevClean                 ║
║   Developed by Suprabhat Chowhan      ║
║   Version 1.0.0  |  Windows-first     ║
╚════════════════════════════════════════╝
```

## Install

### One-liner (recommended)

Paste this in any **PowerShell 7** terminal:

```powershell
irm https://raw.githubusercontent.com/suprabhat/devclean/main/get.ps1 | iex
```

That's it. DevClean downloads itself, installs to `~/.devclean`, and adds `devclean` to your PATH — no Git, no manual steps.

### Manual install

```powershell
git clone https://github.com/suprabhat/devclean
cd devclean
.\install.ps1
```

Restart your terminal, then use `devclean` from anywhere.

> **Requires PowerShell 7+**  
> Install it with: `winget install Microsoft.PowerShell`

---

## Commands

| Command | Description |
|---|---|
| `devclean scan` | Scan all reclaimable storage |
| `devclean cleanup` | Clean all safe targets |
| `devclean cleanup browser` | All browser caches (auto-detects installed browsers) |
| `devclean cleanup chrome` | Chrome cache |
| `devclean cleanup edge` | Edge cache |
| `devclean cleanup brave` | Brave cache |
| `devclean cleanup firefox` | Firefox / LibreWolf / Waterfox / Zen |
| `devclean cleanup gradle` | Gradle cache only |
| `devclean cleanup node` | node_modules only |
| `devclean cleanup sdk` | Android SDK temp files |
| `devclean cleanup temp` | Windows temp files |
| `devclean cleanup --dry-run` | Preview — no deletion |
| `devclean cleanup --interactive` | Step-by-step guided mode |
| `devclean analyze sdk` | Android SDK dependency analysis |
| `devclean analyze node` | node_modules activity analysis |
| `devclean undo` | View last cleanup session |
| `devclean help` | Show help |

---

## Supported Browsers

DevClean auto-detects which browsers are installed and only scans those.

| Browser | Engine | Multi-profile |
|---|---|---|
| Google Chrome | Chromium | ✓ |
| Microsoft Edge | Chromium | ✓ |
| Brave | Chromium | ✓ |
| Vivaldi | Chromium | ✓ |
| Opera / Opera GX | Chromium | — |
| Arc | Chromium | ✓ |
| Chromium | Chromium | ✓ |
| Thorium | Chromium | ✓ |
| Yandex Browser | Chromium | ✓ |
| Samsung Internet | Chromium | — |
| Cốc Cốc | Chromium | — |
| Mozilla Firefox | Gecko | ✓ |
| LibreWolf | Gecko | ✓ |
| Waterfox | Gecko | ✓ |
| Zen Browser | Gecko | ✓ |
| Pale Moon | Goanna | ✓ |
| Internet Explorer | Trident | — |

---



| Label | Meaning |
|---|---|
| `[SAFE]` | Chrome cache, temp files — rebuild automatically |
| `[LOW]` | Gradle cache, node_modules — restore with one command |
| `[MEDIUM]` | Android SDK images, NDK versions — check usage first |
| `[HIGH]` | Actively referenced SDKs — do not remove |

---

## Architecture

```
DevClean/
├── devclean.ps1          # Entry point + command router
├── devclean.psd1         # Module manifest
├── install.ps1           # Installer (adds to PATH)
└── src/
    ├── scanner/          # Per-target scanners
    │   ├── Scan-Chrome.ps1
    │   ├── Scan-NodeModules.ps1
    │   ├── Scan-Gradle.ps1
    │   ├── Scan-AndroidSdk.ps1
    │   └── Scan-WindowsTemp.ps1
    ├── analyzer/         # Dependency-aware analyzers
    │   ├── Analyze-NodeModules.ps1
    │   └── Analyze-AndroidSdk.ps1
    ├── cleanup/          # Deletion + orchestration
    │   ├── Invoke-Cleanup.ps1
    │   └── Send-ToRecycleBin.ps1
    ├── ui/               # Terminal UI components
    │   ├── Show-Banner.ps1
    │   ├── Show-Progress.ps1
    │   ├── Show-ScanTable.ps1
    │   ├── Show-EducationalNote.ps1
    │   └── Show-RiskLabel.ps1
    ├── logs/             # JSON undo log
    │   └── Write-CleanupLog.ps1
    └── utils/            # Shared utilities
        ├── Get-FolderSize.ps1
        └── Format-FileSize.ps1
```

---

## Recycle Bin (Default)

By default, DevClean sends files to the **Windows Recycle Bin**.  
Use `--permanent` only if you want irreversible deletion.

```powershell
devclean cleanup --permanent   # ⚠ Permanent, cannot undo
```

---

## Future Modules (Planned)

- Docker images and volumes
- Python virtual environments (`venv`, `conda`)
- YOLO / AI model weights
- HuggingFace cache (`~/.cache/huggingface`)
- Blender cache
- Unreal Engine derived data cache
- Adobe cache
- Autodesk Maya cache

---

## Requirements

- Windows 10 / 11
- PowerShell 7.0+

---

*DevClean is designed to be safe, transparent, and developer-friendly.*  
*It never deletes source code, package.json, or git repositories.*
