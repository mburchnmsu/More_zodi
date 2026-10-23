# Rounds 31–33 chain: parallax test → pick the winner → full sky map with it → Earth-centric null test.
# Each stage: 5 trainings at a time, below-normal priority. Progress in sweeps\round31.log.
Set-Location C:\JuliaProjects\More_zodi
$env:ZODI_DATA = "z500"; $env:ZODI_HELIO = "1"
$log = "sweeps\round31.log"
function Note($m) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm')  $m" | Out-File $log -Append -Encoding utf8 }
function RunStage($stage) {
    $env:R31_STAGE = $stage
    Note "stage $stage start"
    $p = Start-Process julia -ArgumentList "-t 5 --project=. sweeps/run_threaded.jl sweeps/configs_v31.jl" `
         -RedirectStandardOutput "sweeps\round31_$stage.log" -RedirectStandardError "sweeps\round31_$stage.err" -WindowStyle Hidden -PassThru
    if ($null -eq $p) { Note "stage $stage FAILED to start"; exit 1 }
    Start-Sleep 20
    Get-CimInstance Win32_Process -Filter "ParentProcessId=$($p.Id)" | ForEach-Object { try { (Get-Process -Id $_.ProcessId -ErrorAction Stop).PriorityClass = 'BelowNormal' } catch {} }
    $p.WaitForExit()
    Note "stage $stage done (exit $($p.ExitCode))"
}
RunStage "plx"
& julia --project=. sweeps/decide31.jl *> sweeps\round31_decide.log
$w = (Get-Content sweeps\results_z500_helio\R31_WINNER.txt -ErrorAction SilentlyContinue)
if (-not $w) { $w = "band"; Note "no winner file; defaulting to band" }
$env:R31_WINNER = $w.Trim()
Note "winner: $($env:R31_WINNER)"
RunStage "map"
RunStage "earth"
Note "all stages done"
