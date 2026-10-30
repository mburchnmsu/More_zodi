# Copy finished training results (.jls) from NMSU Discovery back to this PC, so the reports and dated notebooks are
# built and tested here as before. Never overwrites a local file: runs that already exist locally are skipped.
#   powershell -File pipeline\cluster\fetch_results.ps1 -Pattern "z500h_bandplx_cosexp2k_*" [-Results results_z500_helio] [-Dest <dir>]
# -Dest defaults to the matching local folder sweeps\<Results>; give another folder to keep a copy apart
# (e.g. the cluster-vs-laptop check, whose run names already exist locally).
param([Parameter(Mandatory)][string]$Pattern, [string]$Results = "results_z500_helio", [string]$Dest = "")
Set-Location (Join-Path $PSScriptRoot "..\..")
if (-not $Dest) { $Dest = "sweeps\$Results" }
New-Item -ItemType Directory -Force $Dest | Out-Null
$remote = ssh -o BatchMode=yes discovery "cd More_zodi/sweeps/$Results 2>/dev/null && ls -1 $Pattern.jls 2>/dev/null"
if ($LASTEXITCODE -ne 0 -or -not $remote) { Write-Host "no finished runs matching $Pattern.jls on the cluster"; exit 1 }
$new = @($remote | Where-Object { -not (Test-Path (Join-Path $Dest $_)) })
Write-Host "$(@($remote).Count) on the cluster, $($new.Count) new -> $Dest"
foreach ($f in $new) {
    scp -q -o BatchMode=yes "discovery:More_zodi/sweeps/$Results/$f" (Join-Path $Dest "$f.part")
    if ($LASTEXITCODE -eq 0) { Move-Item (Join-Path $Dest "$f.part") (Join-Path $Dest $f) } else { Write-Host "FAILED $f" }
}
