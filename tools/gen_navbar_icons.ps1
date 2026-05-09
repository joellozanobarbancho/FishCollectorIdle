Add-Type -AssemblyName System.Drawing

$SIZE = 24
$OUT  = "c:\Users\jloza\Documents\GitHub\FishCollectorIdle\Assets\UIElements\navbar_icons"

# ---- helpers ---------------------------------------------------------------

function S($bmp, [int]$x, [int]$y, [System.Drawing.Color]$c) {
    if ($x -ge 0 -and $x -lt $SIZE -and $y -ge 0 -and $y -lt $SIZE) {
        $bmp.SetPixel($x, $y, $c)
    }
}

function F($bmp, [int]$x1, [int]$y1, [int]$x2, [int]$y2, [System.Drawing.Color]$c) {
    for ($x = $x1; $x -le $x2; $x++) {
        for ($y = $y1; $y -le $y2; $y++) { S $bmp $x $y $c }
    }
}

# filled box with border
function BF($bmp, [int]$x1, [int]$y1, [int]$x2, [int]$y2,
            [System.Drawing.Color]$bc, [System.Drawing.Color]$fc) {
    F $bmp ($x1+1) ($y1+1) ($x2-1) ($y2-1) $fc
    for ($x = $x1; $x -le $x2; $x++) { S $bmp $x $y1 $bc; S $bmp $x $y2 $bc }
    for ($y = ($y1+1); $y -lt $y2; $y++) { S $bmp $x1 $y $bc; S $bmp $x2 $y $bc }
}

# border only (no fill)
function Bdr($bmp, [int]$x1, [int]$y1, [int]$x2, [int]$y2, [System.Drawing.Color]$bc) {
    for ($x = $x1; $x -le $x2; $x++) { S $bmp $x $y1 $bc; S $bmp $x $y2 $bc }
    for ($y = ($y1+1); $y -lt $y2; $y++) { S $bmp $x1 $y $bc; S $bmp $x2 $y $bc }
}

function New-Bmp { New-Object System.Drawing.Bitmap($SIZE, $SIZE, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb) }
function C([int]$r,[int]$g,[int]$b) { [System.Drawing.Color]::FromArgb(255,$r,$g,$b) }

$OL = C 30 20 10   # dark outline used everywhere

# ============================================================================
# STORE  –  shop house with triangular roof, awning, door, window
# ============================================================================
$bmp = New-Bmp

$R  = C 190 55 35   # roof red-orange
$Rd = C 130 30 15   # roof dark tile
$W  = C 210 175 120 # wall tan
$Wl = C 230 200 150 # wall highlight
$Ag = C 55  140 55  # awning green
$Al = C 100 180 80  # awning stripe
$D  = C 100 55  20  # door brown
$Dl = C 135 82  40  # door highlight
$Wi = C 155 205 225 # window blue
$Wf = C 90  140 160 # window frame
$Sg = C 225 195 75  # sign yellow
$Kn = C 210 180 50  # doorknob gold

# building walls (y=10..22, x=3..20)
F $bmp 3 10 20 22 $W
for ($y = 10; $y -le 22; $y++) { S $bmp 4 $y $Wl }
for ($y = 10; $y -le 22; $y++) { S $bmp 3 $y $OL; S $bmp 20 $y $OL }
for ($x = 3; $x -le 20; $x++) { S $bmp $x 22 $OL }

# roof triangle: apex at (12,2), base at y=9, both edges = outline
for ($row = 2; $row -le 9; $row++) {
    $half = [Math]::Min(9, [int](($row - 2) * 9.0 / 7.0))
    $lx = [Math]::Max(3, 12 - $half)
    $rx = [Math]::Min(20, 12 + $half)
    for ($x = $lx; $x -le $rx; $x++) {
        if ($x -eq $lx -or $x -eq $rx -or $row -eq 2) { S $bmp $x $row $OL }
        elseif (($x + $row) % 3 -eq 0) { S $bmp $x $row $Rd }
        else { S $bmp $x $row $R }
    }
}
for ($x = 3; $x -le 20; $x++) { S $bmp $x 9 $OL }   # roof base line

# awning (y=10-11, alternating stripes)
for ($x = 4; $x -le 19; $x++) {
    $c = if ($x % 2 -eq 0) { $Ag } else { $Al }
    S $bmp $x 10 $c; S $bmp $x 11 $c
}
for ($x = 3; $x -le 20; $x++) { S $bmp $x 12 $OL }   # awning bottom edge

# window (x=4..8, y=14..18) with cross
BF $bmp 4 14 8 18 $OL $Wi
for ($y = 14; $y -le 18; $y++) { S $bmp 6 $y $Wf }
for ($x = 4; $x -le 8; $x++) { S $bmp $x 16 $Wf }

# door (x=11..15, y=14..22)
BF $bmp 11 14 15 22 $OL $D
for ($y = 15; $y -le 21; $y++) { S $bmp 12 $y $Dl }
S $bmp 14 18 $Kn   # knob

# sign (x=17..20, y=14..17)
BF $bmp 17 14 20 17 $OL $Sg
for ($x = 18; $x -le 19; $x++) { S $bmp $x 15 $OL; S $bmp $x 16 $OL }

$bmp.Save("$OUT\store.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose(); Write-Host "store.png saved"

# ============================================================================
# INVENTORY  –  backpack: orange body, arch handle, zipper, front pocket
# ============================================================================
$bmp = New-Bmp

$Mb = C 220 110 20   # main orange
$Ml = C 255 160 55   # highlight orange
$Md = C 155 70  5    # dark orange / shadow
$St = C 95  40  5    # handle dark brown
$Pk = C 180 80  8    # front pocket (darker orange)
$Zp = C 245 225 175  # zipper light cream

# Handle: inverted-U arch at top center (x=8..15, y=2..4), open at bottom
for ($x = 9; $x -le 14; $x++) { S $bmp $x 2 $OL }   # top bar outline
for ($x = 10; $x -le 13; $x++) { S $bmp $x 2 $St; S $bmp $x 3 $St }
for ($y = 2; $y -le 4; $y++) {
    S $bmp 8  $y $OL; S $bmp 9  $y $St
    S $bmp 15 $y $OL; S $bmp 14 $y $St
}

# Main body fill + shading (y=5..22, x=3..20)
F $bmp 3 5 20 22 $Mb
for ($y = 5; $y -le 22; $y++) { S $bmp 4 $y $Ml; S $bmp 19 $y $Md }
for ($x = 3; $x -le 20; $x++) { S $bmp $x 6 $Ml }
Bdr $bmp 3 5 20 22 $OL

# Zipper dashes (y=13)
for ($x = 4; $x -le 19; $x++) {
    $zc = if ($x % 2 -eq 0) { $Zp } else { $Md }
    S $bmp $x 13 $zc
}
S $bmp 3 13 $OL; S $bmp 20 13 $OL

# Front pocket fill + shading + border (y=14..21, x=6..17)
F $bmp 6 14 17 21 $Pk
for ($y = 14; $y -le 21; $y++) { S $bmp 7 $y $Ml }
Bdr $bmp 6 14 17 21 $OL

$bmp.Save("$OUT\inventory.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose(); Write-Host "inventory.png saved"

# ============================================================================
# QUESTS  –  scroll (rolls top+bottom) with parchment, text lines, quill
# ============================================================================
$bmp = New-Bmp

$Pa = C 225 200 150   # parchment
$Pd = C 190 160 100   # parchment shadow
$Ro = C 175 135 75    # roll brown
$Rl = C 210 175 115   # roll highlight
$Tk = C 80  55  25    # ink
$Qu = C 240 240 220   # quill
$Qb = C 185 180 160   # quill barb
$Qn = C 40  28  10    # quill nib

# top roll (y=2..5)
F $bmp 2 2 21 5 $Ro
for ($x = 3; $x -le 20; $x++) { S $bmp $x 3 $Rl; S $bmp $x 5 $Pd }
Bdr $bmp 2 2 21 5 $OL

# bottom roll (y=19..22)
F $bmp 2 19 21 22 $Ro
for ($x = 3; $x -le 20; $x++) { S $bmp $x 20 $Rl; S $bmp $x 19 $Pd }
Bdr $bmp 2 19 21 22 $OL

# parchment body (y=6..18)
F $bmp 4 6 19 18 $Pa
for ($y = 6; $y -le 18; $y++) { S $bmp 5 $y $Pd }
Bdr $bmp 4 6 19 18 $OL

# text lines
for ($x = 6; $x -le 17; $x++) { S $bmp $x 8 $Tk }
for ($x = 6; $x -le 15; $x++) { S $bmp $x 10 $Tk }
for ($x = 6; $x -le 17; $x++) { S $bmp $x 12 $Tk }
for ($x = 6; $x -le 14; $x++) { S $bmp $x 14 $Tk }
for ($x = 6; $x -le 16; $x++) { S $bmp $x 16 $Tk }

# quill (diagonal, top-right to bottom-left)
for ($i = 0; $i -le 7; $i++) {
    S $bmp (20-$i) (2+$i) $Qu
    S $bmp (19-$i) (2+$i) $Qb
    if ($i -gt 0) { S $bmp (20-$i) (1+$i) $Qb }
}
# nib
S $bmp 13 9 $Qn; S $bmp 12 10 $Qn; S $bmp 11 11 $Qn

$bmp.Save("$OUT\quests.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose(); Write-Host "quests.png saved"

# ============================================================================
# SOCIAL  –  speech bubble (rounded rect) with tail and three dots
# ============================================================================
$bmp = New-Bmp

$Bu = C 255 255 255   # bubble white
$Bl = C 228 228 228   # highlight light gray
$Bd = C 185 185 185   # shadow medium gray
$Dt = C 45  45  45    # dot color dark gray

# rounded rect body
F $bmp 4 1 19 16 $Bu
F $bmp 2 3 21 14 $Bu
S $bmp 3 2 $Bu; S $bmp 20 2 $Bu
S $bmp 3 15 $Bu; S $bmp 20 15 $Bu

# highlights (top + left edge)
for ($x = 5; $x -le 18; $x++) { S $bmp $x 2 $Bl }
for ($y = 3; $y -le 14; $y++) { S $bmp 3 $y $Bl }
# shadows (bottom + right edge)
for ($x = 4; $x -le 19; $x++) { S $bmp $x 15 $Bd }
for ($y = 3; $y -le 14; $y++) { S $bmp 20 $y $Bd }

# outline
for ($x = 4; $x -le 19; $x++) { S $bmp $x 1 $OL; S $bmp $x 16 $OL }
for ($y = 3; $y -le 14; $y++) { S $bmp 2 $y $OL; S $bmp 21 $y $OL }
S $bmp 3 2 $OL; S $bmp 20 2 $OL
S $bmp 3 15 $OL; S $bmp 20 15 $OL

# tail (bottom-right pointing down)
S $bmp 18 17 $Bu; S $bmp 19 17 $Bu
S $bmp 19 18 $Bu; S $bmp 20 18 $Bu
S $bmp 20 19 $Bu; S $bmp 21 19 $Bu
S $bmp 21 20 $Bu
# tail outline
S $bmp 17 17 $OL; S $bmp 20 17 $OL
S $bmp 18 18 $OL; S $bmp 21 18 $OL
S $bmp 19 19 $OL; S $bmp 22 19 $OL
S $bmp 20 20 $OL; S $bmp 22 20 $OL
S $bmp 21 21 $OL; S $bmp 22 21 $OL

# three dots (2x2 each, centered vertically)
for ($dot = 0; $dot -le 2; $dot++) {
    $dx = 6 + $dot * 5
    S $bmp $dx 8 $Dt; S $bmp ($dx+1) 8 $Dt
    S $bmp $dx 9 $Dt; S $bmp ($dx+1) 9 $Dt
}

$bmp.Save("$OUT\social.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose(); Write-Host "social.png saved"

# ============================================================================
# OPTIONS  –  gear with 8 teeth and center hole
# ============================================================================
$bmp = New-Bmp

$Ge = C 155 155 165   # gear mid-gray
$Gl = C 195 195 208   # gear highlight
$Gd = C 105 105 118   # gear shadow

$cx = 11.5; $cy = 11.5
$outer_r = 9.5; $inner_r = 6.5; $hole_r = 3.0
$teeth = 8; $tf = 0.38   # fraction of arc that is tooth

for ($y = 0; $y -lt $SIZE; $y++) {
    for ($x = 0; $x -lt $SIZE; $x++) {
        $dx = $x - $cx; $dy = $y - $cy
        $dist = [Math]::Sqrt($dx*$dx + $dy*$dy)
        if ($dist -lt $hole_r) { continue }
        $angle = [Math]::Atan2($dy, $dx)
        $ta = 2 * [Math]::PI / $teeth
        $na = $angle % $ta
        if ($na -lt 0) { $na += $ta }
        $in_tooth = ($na -lt ($ta * $tf) -or $na -gt ($ta * (1 - $tf)))
        if ($dist -le $inner_r -or ($dist -le $outer_r -and $in_tooth)) {
            if ($dx -lt -0.5 -and $dy -lt -0.5) { S $bmp $x $y $Gl }
            elseif ($dx -gt 0.5 -and $dy -gt 0.5) { S $bmp $x $y $Gd }
            else { S $bmp $x $y $Ge }
        }
    }
}

# collect opaque pixels then outline their empty neighbours
$gp = New-Object 'System.Collections.Generic.HashSet[string]'
for ($y = 0; $y -lt $SIZE; $y++) {
    for ($x = 0; $x -lt $SIZE; $x++) {
        if ($bmp.GetPixel($x,$y).A -gt 0) { [void]$gp.Add("$x,$y") }
    }
}
$ops = [System.Collections.Generic.List[string]]::new()
foreach ($k in $gp) {
    $pt = $k.Split(','); $ox = [int]$pt[0]; $oy = [int]$pt[1]
    foreach ($n in @("$($ox+1),$oy","$($ox-1),$oy","$ox,$($oy+1)","$ox,$($oy-1)")) {
        if (-not $gp.Contains($n)) {
            $np = $n.Split(',')
            $nx = [int]$np[0]; $ny = [int]$np[1]
            if ($nx -ge 0 -and $nx -lt $SIZE -and $ny -ge 0 -and $ny -lt $SIZE) {
                $ops.Add($n)
            }
        }
    }
}
foreach ($p in ($ops | Select-Object -Unique)) {
    $pt = $p.Split(','); S $bmp ([int]$pt[0]) ([int]$pt[1]) $OL
}

# center hole ring outline
for ($y = 0; $y -lt $SIZE; $y++) {
    for ($x = 0; $x -lt $SIZE; $x++) {
        $dx = $x - $cx; $dy = $y - $cy
        $dist = [Math]::Sqrt($dx*$dx + $dy*$dy)
        if ($dist -ge ($hole_r - 0.7) -and $dist -le ($hole_r + 0.4)) {
            S $bmp $x $y $OL
        }
    }
}

$bmp.Save("$OUT\options.png", [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose(); Write-Host "options.png saved"

Write-Host "All 5 navbar icons generated in $OUT"
