# Wait for the given julia processes to exit, then start N training lanes for a config file.
#   powershell -File queue_lanes.ps1 -WaitPids "1,2,3" -Config sweeps/configs_v11.jl -Lanes 4 -Tag v11 [-ZodiData z115] [-Priority Normal]
#   or wait for result files:  -WaitGlob "sweeps\results_z115\z115_sun*.jls" -WaitCount 40
param([string]$WaitPids = "", [string]$WaitGlob = "", [int]$WaitCount = 0, [string]$Config, [int]$Lanes = 4, [string]$Tag,
      [string]$ZodiData = "z115", [string]$Priority = "Normal")
$root = "C:\JuliaProjects\More_zodi"; Set-Location $root
$resdir = if ($ZodiData -eq "original") { "sweeps\results" } else { "sweeps\results_$ZodiData" }
New-Item -ItemType Directory -Force $resdir | Out-Null
$pids = @($WaitPids -split "[,\s]+" | Where-Object { $_ } | ForEach-Object { [int]$_ })
"$(Get-Date -Format s) waiting for pids [$($pids -join ',')] and $WaitCount files matching '$WaitGlob'" | Out-File -Append "$resdir\queue_$Tag.txt"
foreach ($id in $pids) { try { Wait-Process -Id $id -ErrorAction Stop } catch {} }
if ($WaitGlob) { while (@(Get-ChildItem $WaitGlob -ErrorAction SilentlyContinue).Count -lt $WaitCount) { Start-Sleep 60 } }
Start-Sleep 30    # let the finishing lanes exit and free their memory
$env:ZODI_DATA = $ZodiData; $env:SLURM_ARRAY_TASK_COUNT = "$Lanes"
$launched = @()
foreach ($i in 1..$Lanes) {
    $env:SLURM_ARRAY_TASK_ID = "$i"
    $p = Start-Process julia -ArgumentList '--project=.', 'pipeline/cluster/run_lane.jl', $Config `
         -RedirectStandardOutput "$resdir\lane${i}_$Tag.log" -RedirectStandardError "$resdir\lane${i}_$Tag.err" -PassThru -WindowStyle Hidden
    $launched += $p.Id
}
Start-Sleep 10
foreach ($id in $launched) {
    Get-CimInstance Win32_Process | Where-Object { $_.ParentProcessId -eq $id } | ForEach-Object {
        try { (Get-Process -Id $_.ProcessId).PriorityClass = $Priority } catch {} }
}
"$(Get-Date -Format s) launched $Lanes lanes for $Config (parents $($launched -join ','))" | Out-File -Append "$resdir\queue_$Tag.txt"
