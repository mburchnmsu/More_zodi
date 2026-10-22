# Round 30 launcher: waits for round 29 ("all stages done" in sweeps\round29.log), then trains the learnable-band runs.
Set-Location C:\JuliaProjects\More_zodi
while (-not (Select-String -Path sweeps\round29.log -Pattern "all stages done" -Quiet)) { Start-Sleep 60 }
$env:ZODI_DATA = "z500"; $env:ZODI_HELIO = "1"
"$(Get-Date -Format 'yyyy-MM-dd HH:mm')  round 30 start" | Out-File sweeps\round30.log -Append -Encoding utf8
$p = Start-Process julia -ArgumentList "-t 5 --project=. sweeps/run_threaded.jl sweeps/configs_v30.jl" -RedirectStandardOutput sweeps\round30_run.log `
     -RedirectStandardError sweeps\round30_run.err -WindowStyle Hidden -PassThru
if ($null -eq $p) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm')  FAILED to start" | Out-File sweeps\round30.log -Append -Encoding utf8; exit 1 }
Start-Sleep 20
Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" | ForEach-Object { try { (Get-Process -Id $_.ProcessId -ErrorAction Stop).PriorityClass = 'BelowNormal' } catch {} }
$p.WaitForExit()
"$(Get-Date -Format 'yyyy-MM-dd HH:mm')  round 30 done (exit $($p.ExitCode))" | Out-File sweeps\round30.log -Append -Encoding utf8
