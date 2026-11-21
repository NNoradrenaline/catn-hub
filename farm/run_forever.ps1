# Keeps one Node script running: starts it again 15 s after it exits or crashes.
# Both scripts refuse to start a second copy, so a spare runner only idles.
param([Parameter(Mandatory)][string]$Dir, [Parameter(Mandatory)][string]$Script, [string]$Log = "run.log")
Set-Location -LiteralPath $Dir
while ($true) {
    cmd /c "node `"$Script`" >> `"$Log`" 2>&1"
    Start-Sleep -Seconds 15
}
