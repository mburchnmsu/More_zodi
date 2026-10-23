# Round 34: parallax band layer, 2000 epochs, 6 shifts × 5 seeds (~65 h), 5 trainings at a time, below-normal priority.
# Safe to rerun after a crash/reboot: finished runs are skipped. Progress in sweeps\round34.log.
Set-Location C:\JuliaProjects\More_zodi
$env:ZODI_DATA = "z500"; $env:ZODI_HELIO = "1"
$log = "sweeps\round34.log"
function Note($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm')  $m" | Out-File $log -Append -Encoding utf8 }
Note "round 34 start"
$p = Start-Process julia -ArgumentList "-t 5 --project=. sweeps/run_threaded.jl sweeps/configs_v34.jl" `
     -RedirectStandardOutput "sweeps\round34_run.log" -RedirectStandardError "sweeps\round34_run.err" -WindowStyle Hidden -PassThru
if ($null -eq $p) { Note "FAILED to start"; exit 1 }
Start-Sleep 20
Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" | ForEach-Object { try { (Get-Process -Id $_.ProcessId -ErrorAction Stop).PriorityClass = 'BelowNormal' } catch {} }
try { $p.PriorityClass = 'BelowNormal' } catch {}
$p.WaitForExit()
Note "round 34 done"
