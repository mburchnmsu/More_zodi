# Round 27 launcher: waits until 22:00 on 2026-10-20 (the user's deadline), then starts the heliocentric no-n·J test unless
# sweeps\CANCEL_round27 exists (the user can say "don't run it" before then). Below-normal priority.
Set-Location C:\JuliaProjects\More_zodi
$start = Get-Date "2026-10-20 22:00"
while ((Get-Date) -lt $start) { Start-Sleep 30 }
if (Test-Path sweeps\CANCEL_round27) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm')  round 27 cancelled" | Out-File sweeps\round27.log -Append -Encoding utf8; exit }
$env:ZODI_DATA = "z500"; $env:ZODI_HELIO = "1"
"$(Get-Date -Format 'yyyy-MM-dd HH:mm')  round 27 start" | Out-File sweeps\round27.log -Append -Encoding utf8
$p = Start-Process julia -ArgumentList "-t 5 --project=. sweeps/run_threaded.jl sweeps/configs_v27.jl" -RedirectStandardOutput sweeps\round27_run.log `
     -RedirectStandardError sweeps\round27_run.err -WindowStyle Hidden -PassThru
Start-Sleep 10
Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" | ForEach-Object { try { (Get-Process -Id $_.ProcessId -ErrorAction Stop).PriorityClass = 'BelowNormal' } catch {} }
$p.WaitForExit()
"$(Get-Date -Format 'yyyy-MM-dd HH:mm')  round 27 done" | Out-File sweeps\round27.log -Append -Encoding utf8
