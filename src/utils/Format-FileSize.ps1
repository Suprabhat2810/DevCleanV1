function Format-FileSize {
    param([long]$Bytes)

    if     ($Bytes -ge 1TB) { return "{0:N1} TB" -f ($Bytes / 1TB) }
    elseif ($Bytes -ge 1GB) { return "{0:N1} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { return "{0:N1} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { return "{0:N1} KB" -f ($Bytes / 1KB) }
    else                    { return "$Bytes B" }
}

function Format-Age {
    param([datetime]$LastModified)

    $age = (Get-Date) - $LastModified

    if     ($age.Days -ge 365) { return "{0} year(s) ago"  -f [math]::Floor($age.Days / 365) }
    elseif ($age.Days -ge 30)  { return "{0} month(s) ago" -f [math]::Floor($age.Days / 30) }
    elseif ($age.Days -ge 1)   { return "{0} day(s) ago"   -f $age.Days }
    else                       { return "Today" }
}
