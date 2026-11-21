# Keeps Roblox from closing older clients when another Roblox process starts (multi-account farming).
# Roblox 0.7xx hands over to the newest client through the named mutex ROBLOX_singletonMutex; while this
# process owns it, no client can take it, so none of them shut themselves down. Close this to undo.
$log = Join-Path $PSScriptRoot "hold_roblox_mutex.log"
$created = $false
$m = New-Object System.Threading.Mutex($true, "ROBLOX_singletonMutex", [ref]$created)
$owned = $created
if (-not $owned) {
    try { $owned = $m.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $owned = $true }
}
"$(Get-Date -Format s) started pid $PID, created=$created owned=$owned" | Out-File $log -Append -Encoding utf8
while (-not $owned) {
    # a Roblox client holds it right now: keep trying, and take it the moment it is free
    try { $owned = $m.WaitOne(5000) } catch [System.Threading.AbandonedMutexException] { $owned = $true }
    if ($owned) { "$(Get-Date -Format s) acquired" | Out-File $log -Append -Encoding utf8 }
}
while ($true) { Start-Sleep -Seconds 3600 }
