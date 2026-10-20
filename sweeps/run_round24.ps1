# Round 24 launcher: the 30 trainings of configs_v24.jl in three stages (shifts 0+30, 10+40, 20+50), so the most useful
# versions finish first; each stage runs 5 trainings at a time, below-normal priority.   powershell -File sweeps\run_round24.ps1
Set-Location C:\JuliaProjects\More_zodi
$env:ZODI_DATA = "z500"
$log = "sweeps\round24.log"
foreach ($pair in @(@(0, 30), @(10, 40), @(20, 50))) {
    $names = foreach ($d in $pair) { foreach ($s in 42..46) { "z500_nJ_shift${d}_s$s" } }
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm')  stage: shifts $($pair -join ' + ')" | Out-File $log -Append -Encoding utf8
    $p = Start-Process julia -ArgumentList "-t 5 --project=. sweeps/run_threaded.jl sweeps/configs_v24.jl --only $($names -join ',')" `
         -RedirectStandardOutput "sweeps\round24_stage_$($pair -join '_').log" -RedirectStandardError "sweeps\round24_stage_$($pair -join '_').err" `
         -WindowStyle Hidden -PassThru
    Start-Sleep 10
    Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" | ForEach-Object { try { (Get-Process -Id $_.ProcessId -ErrorAction Stop).PriorityClass = 'BelowNormal' } catch {} }
    $p.WaitForExit()
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm')  stage done (exit $($p.ExitCode))" | Out-File $log -Append -Encoding utf8
}
"$(Get-Date -Format 'yyyy-MM-dd HH:mm')  all stages done" | Out-File $log -Append -Encoding utf8
