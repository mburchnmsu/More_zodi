# Round 38: cos×exp at 1000 epochs, shifts 10/20/40/50 × 5 seeds, parallax band layer (~26 h), at below-normal priority.
# Optional: -WaitPid <pid> waits for another process to exit; -WaitFile <path> waits for another job's done-marker file
# (read only; e.g. Solar R4 writes ...\SolarFlareForcast\sweeps\results\.lowprio_done). Then waits until >= 6 GB RAM is free.
# Safe to rerun: finished runs are skipped. Progress in sweeps\round38.log.
#   powershell -File sweeps\run_round38.ps1 [-WaitPid 1234] [-WaitFile C:\path\to\marker]
param([int]$WaitPid = 0, [string]$WaitFile = "")
Set-Location C:\JuliaProjects\More_zodi
$env:ZODI_DATA = "z500"; $env:ZODI_HELIO = "1"
$log = "sweeps\round38.log"
function Note($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm')  $m" | Out-File $log -Append -Encoding utf8 }
function FreeGB { (Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB }
if ($WaitPid -gt 0) {
    Note "waiting for PID $WaitPid to exit"
    while (Get-Process -Id $WaitPid -ErrorAction SilentlyContinue) { Start-Sleep 120 }
}
if ($WaitFile) {
    Note "waiting for $WaitFile"
    while (-not (Test-Path -LiteralPath $WaitFile)) { Start-Sleep 120 }
    Note "found $WaitFile"
}
while ((FreeGB) -lt 6) { Start-Sleep 300 }
Note ("round 38 start ({0:N1} GB free)" -f (FreeGB))
$p = Start-Process julia -ArgumentList "-t 5 --project=. sweeps/run_threaded.jl sweeps/configs_v38.jl" `
     -RedirectStandardOutput "sweeps\round38_run.log" -RedirectStandardError "sweeps\round38_run.err" -WindowStyle Hidden -PassThru
if ($null -eq $p) { Note "FAILED to start"; exit 1 }
Start-Sleep 20
Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" | ForEach-Object { try { (Get-Process -Id $_.ProcessId -ErrorAction Stop).PriorityClass = 'BelowNormal' } catch {} }
try { $p.PriorityClass = 'BelowNormal' } catch {}
$p.WaitForExit()
Note "round 38 done"
