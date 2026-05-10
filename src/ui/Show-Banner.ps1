function Show-Banner {
    $banner = @"

  ╔════════════════════════════════════════╗
  ║              DevClean                 ║
  ║   Developed by Suprabhat Chowhan      ║
  ║   Version 1.0.0  |  Windows-first     ║
  ╚════════════════════════════════════════╝

"@
    Write-Host $banner -ForegroundColor Cyan
}
