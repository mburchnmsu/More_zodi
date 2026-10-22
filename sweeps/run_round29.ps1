# Round 29 launcher: shifts 10 + 40, then 20 + 50 (heliocentric 500-day map), 5 trainings at a time, below-normal priority.
Set-Location C:\JuliaProjects\More_zodi
$env:ZODI_DATA = "z500"; $env:ZODI_HELIO = "1"
$log = "sweeps\round29.log"
foreach ($pair in @(@(10, 40), @(20, 50))) {
    $names = ($pair | ForEach-Object { $d = $_; 42..46 | ForEach-Object { "z500h_noJ_shift${d}_s$_" } }) -join ","
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm')  stage: shifts $($pair -join ' + ')" | Out-File $log -Append -Encoding utf8
    $p = Start-Process julia -ArgumentList "-t 5 --project=. sweeps/run_threaded.jl sweeps/configs_v29.jl --only $names" `
         -RedirectStandardOutput "sweeps\round29_$($pair -join '_').log" -RedirectStandardError "sweeps\round29_$($pair -join '_').err" `
         -WindowStyle Hidden -PassThru
    if ($null -eq $p) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm')  FAILED to start" | Out-File $log -Append -Encoding utf8; exit 1 }
    Start-Sleep 20
    Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" | ForEach-Object { try { (Get-Process -Id $_.ProcessId -ErrorAction Stop).PriorityClass = 'BelowNormal' } catch {} }
    $p.WaitForExit()
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm')  stage done (exit $($p.ExitCode))" | Out-File $log -Append -Encoding utf8
}
"$(Get-Date -Format 'yyyy-MM-dd HH:mm')  all stages done" | Out-File $log -Append -Encoding utf8
