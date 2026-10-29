# Round 37: cos×exp schedule at 1000 epochs, shifts 0 and 30 × 5 seeds, parallax band layer (~12–13 h), at below-normal
# priority. Safe to rerun: finished runs are skipped. Progress in sweeps\round37.log.
#   powershell -File sweeps\run_round37.ps1
Set-Location C:\JuliaProjects\More_zodi
$env:ZODI_DATA = "z500"; $env:ZODI_HELIO = "1"
$log = "sweeps\round37.log"
function Note($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm')  $m" | Out-File $log -Append -Encoding utf8 }
Note "round 37 start"
$p = Start-Process julia -ArgumentList "-t 5 --project=. sweeps/run_threaded.jl sweeps/configs_v37.jl" `
     -RedirectStandardOutput "sweeps\round37_run.log" -RedirectStandardError "sweeps\round37_run.err" -WindowStyle Hidden -PassThru
if ($null -eq $p) { Note "FAILED to start"; exit 1 }
Start-Sleep 20
Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" | ForEach-Object { try { (Get-Process -Id $_.ProcessId -ErrorAction Stop).PriorityClass = 'BelowNormal' } catch {} }
try { $p.PriorityClass = 'BelowNormal' } catch {}
$p.WaitForExit()
Note "round 37 done"
