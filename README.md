# DevClean

> **Developer-aware workstation cleanup CLI for Windows**

```
╔════════════════════════════════════════╗
║              DevClean                 ║
║   Developed by Suprabhat Chowhan      ║
║   Version 1.0.0  |  Windows-first     ║
╚════════════════════════════════════════╝
```

---

## Install

### One-liner (recommended)

Paste this in any **PowerShell** terminal (5.1+ or 7+):

```powershell
irm https://github.com/Suprabhat2810/DevCleanV1/releases/latest/download/get.ps1 | iex
```

That's it. DevClean downloads itself, installs to `~/.devclean`, and adds `devclean` to your PATH — no Git, no manual steps.

### Manual install

1. Download `devclean.exe` from the [latest release](https://github.com/Suprabhat2810/DevCleanV1/releases/latest)
2. Place it in a folder (e.g. `C:\Users\YourName\.devclean\`)
3. Add that folder to your system PATH

Restart your terminal, then use `devclean` from anywhere.

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

### Flags

| Flag | Description |
|---|---|
| `--dry-run` | Simulate cleanup, no files deleted |
| `--interactive` | Confirm each category before cleanup |
| `--permanent` | Permanently delete (default: Recycle Bin) |

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

## Risk Levels

| Label | Meaning |
|---|---|
| `[SAFE]` | Browser cache, temp files — rebuild automatically |
| `[LOW]` | Gradle cache, node_modules — restore with one command |
| `[MEDIUM]` | Android SDK images, NDK versions — check usage first |
| `[HIGH]` | Actively referenced SDKs — do not remove |

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
- PowerShell 5.1+ (comes with Windows) or PowerShell 7+

---

## Uninstall

```powershell
Remove-Item "$env:USERPROFILE\.devclean" -Recurse -Force
```

Then remove `C:\Users\YourName\.devclean` from your system PATH.

---

*DevClean is designed to be safe, transparent, and developer-friendly.*
*It never deletes source code, package.json, or git repositories.*

**Developed by [Suprabhat Chowhan](https://github.com/Suprabhat2810)**
