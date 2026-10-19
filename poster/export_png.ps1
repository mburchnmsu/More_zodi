# Export poster_{light,dark}<suffix>.pptx to PNG previews (and PDF) with PowerPoint.
#   powershell -File poster\export_png.ps1 [-suffix _35]
param([string]$suffix = "")
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pp = New-Object -ComObject PowerPoint.Application
try {
    foreach ($t in "light", "dark") {
        $p = $pp.Presentations.Open("$dir\poster_$t$suffix.pptx", $true, $false, $false)   # read-only, no window
        $p.Slides(1).Export("$dir\preview_$t$suffix.png", "PNG", 1800, 2400)
        $p.SaveAs("$dir\poster_$t$suffix.pdf", 32)                                         # 32 = ppSaveAsPDF
        $p.Close(); "exported $t$suffix"
    }
} finally { $pp.Quit() }
