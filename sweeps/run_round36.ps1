# Round 36: cos×exp schedule on shifts 10, 20, 40, 50 × 5 seeds, parallax band layer, 500 epochs (~11 h), at below-normal
# priority. Safe to rerun: finished runs are skipped. Progress in sweeps\round36.log.
#   powershell -File sweeps\run_round36.ps1
Set-Location C:\JuliaProjects\More_zodi
$env:ZODI_DATA = "z500"; $env:ZODI_HELIO = "1"
$log = "sweeps\round36.log"
function Note($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm')  $m" | Out-File $log -Append -Encoding utf8 }
Note "round 36 start"
$p = Start-Process julia -ArgumentList "-t 5 --project=. sweeps/run_threaded.jl sweeps/configs_v36.jl" `
     -RedirectStandardOutput "sweeps\round36_run.log" -RedirectStandardError "sweeps\round36_run.err" -WindowStyle Hidden -PassThru
if ($null -eq $p) { Note "FAILED to start"; exit 1 }
Start-Sleep 20
Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" | ForEach-Object { try { (Get-Process -Id $_.ProcessId -ErrorAction Stop).PriorityClass = 'BelowNormal' } catch {} }
try { $p.PriorityClass = 'BelowNormal' } catch {}
$p.WaitForExit()
Note "round 36 done"
