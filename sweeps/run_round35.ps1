# Round 35: cos×exp learning-rate schedule (with warm-up) vs one-cycle, parallax band layer, 500 epochs, shifts 0 and 30
# × 5 seeds (~5.5 h). Waits for round 34 to finish (all 30 runs saved and its Julia worker exited), then starts at
# below-normal priority. Safe to rerun: finished runs are skipped. Progress in sweeps\round35.log.
#   powershell -File sweeps\run_round35.ps1 [-Wait34Pid <round 34's julia worker PID>]
param([int]$Wait34Pid = 0)
Set-Location C:\JuliaProjects\More_zodi
$env:ZODI_DATA = "z500"; $env:ZODI_HELIO = "1"
$log = "sweeps\round35.log"
function Note($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm')  $m" | Out-File $log -Append -Encoding utf8 }
$res = "sweeps\results_z500_helio"
Note "round 35 queued, waiting for round 34"
while (@(Get-ChildItem $res -Filter "z500h_bandplx2k_shift*_s*.jls").Count -lt 30 -or
       ($Wait34Pid -gt 0 -and $null -ne (Get-Process -Id $Wait34Pid -ErrorAction SilentlyContinue))) {
    Start-Sleep 300
}
Note "round 35 start"
$p = Start-Process julia -ArgumentList "-t 5 --project=. sweeps/run_threaded.jl sweeps/configs_v35.jl" `
     -RedirectStandardOutput "sweeps\round35_run.log" -RedirectStandardError "sweeps\round35_run.err" -WindowStyle Hidden -PassThru
if ($null -eq $p) { Note "FAILED to start"; exit 1 }
Start-Sleep 20
Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" | ForEach-Object { try { (Get-Process -Id $_.ProcessId -ErrorAction Stop).PriorityClass = 'BelowNormal' } catch {} }
try { $p.PriorityClass = 'BelowNormal' } catch {}
$p.WaitForExit()
Note "round 35 done"
