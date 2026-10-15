# Export poster_{light,dark}.pptx to PNG previews (and PDF) with PowerPoint.   powershell -File poster\export_png.ps1
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pp = New-Object -ComObject PowerPoint.Application
try {
    foreach ($t in "light", "dark") {
        $p = $pp.Presentations.Open("$dir\poster_$t.pptx", $true, $false, $false)   # read-only, no window
        $p.Slides(1).Export("$dir\preview_$t.png", "PNG", 1800, 2400)
        $p.SaveAs("$dir\poster_$t.pdf", 32)                                         # 32 = ppSaveAsPDF
        $p.Close(); "exported $t"
    }
} finally { $pp.Quit() }
