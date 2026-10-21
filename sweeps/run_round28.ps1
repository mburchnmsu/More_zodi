# Round 28 launcher: stage 1 = heliocentric shift 30 (completes the sky map), stage 2 = heliocentric + n·J (Jupiter null).
Set-Location C:\JuliaProjects\More_zodi
$env:ZODI_DATA = "z500"; $env:ZODI_HELIO = "1"
$log = "sweeps\round28.log"
foreach ($stage in @(@("shift30", "z500h_noJ_shift30"), @("nJ", "z500h_nJ_shift0"))) {
    $names = (42..46 | ForEach-Object { "$($stage[1])_s$_" }) -join ","
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm')  stage $($stage[0]) start" | Out-File $log -Append -Encoding utf8
    $p = Start-Process julia -ArgumentList "-t 5 --project=. sweeps/run_threaded.jl sweeps/configs_v28.jl --only $names" `
         -RedirectStandardOutput "sweeps\round28_$($stage[0]).log" -RedirectStandardError "sweeps\round28_$($stage[0]).err" -WindowStyle Hidden -PassThru
    Start-Sleep 10
    Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" | ForEach-Object { try { (Get-Process -Id $_.ProcessId -ErrorAction Stop).PriorityClass = 'BelowNormal' } catch {} }
    $p.WaitForExit()
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm')  stage $($stage[0]) done" | Out-File $log -Append -Encoding utf8
}
