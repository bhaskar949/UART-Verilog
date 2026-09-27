# ============================================================
# UART Simulation in PowerShell — Bit-level behavioral model
# ============================================================
param([int]$DataBits=8, [int]$StopBits=1, [int]$Oversampling=16)

function Get-UARTFrame($byte) {
    $bits = @(0)  # START bit
    for ($i=0; $i -lt $DataBits; $i++) { $bits += ($byte -shr $i) -band 1 }  # Data LSB first
    for ($i=0; $i -lt $StopBits; $i++) { $bits += 1 }  # STOP bit(s)
    return $bits
}

function UART-RX($bits, $DataBits, $Oversampling) {
    $ticks = @()
    foreach ($b in $bits) { for($i=0; $i -lt $Oversampling; $i++) { $ticks += $b } }

    # Detect start bit
    $idx = 0
    while ($idx -lt $ticks.Count -and $ticks[$idx] -ne 0) { $idx++ }
    if ($idx -ge $ticks.Count) { return $null }

    # Centre of start bit
    $centre = $idx + [int]($Oversampling/2)
    if ($ticks[$centre] -ne 0) { return $null }  # False start

    # Sample each data bit at centre
    $data = 0
    for ($bit=0; $bit -lt $DataBits; $bit++) {
        $sampleAt = $centre + $Oversampling + ($bit * $Oversampling)
        if ($sampleAt -lt $ticks.Count) {
            $data = $data -bor ($ticks[$sampleAt] -shl $bit)
        }
    }
    return $data
}

$testBytes = @(0xA5, 0x55, 0xAA, 0xFF, 0x00, [byte][char]'U', [byte][char]'A', [byte][char]'R', [byte][char]'T')
$pass = 0; $fail = 0

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "  UART PowerShell Behavioral Simulation" -ForegroundColor Cyan
Write-Host "  DATA_BITS=$DataBits  STOP_BITS=$StopBits  OVERSAMPLING=$Oversampling" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host ("{0,-5} {1,-10} {2,-10} {3,-10} {4,-10} {5}" -f "Test","TX Byte","TX Hex","RX Byte","RX Hex","Result")
Write-Host ("-" * 65)

$i = 1
foreach ($txByte in $testBytes) {
    $frame  = Get-UARTFrame $txByte
    $rxByte = UART-RX $frame $DataBits $Oversampling
    if ($rxByte -eq $txByte) {
        $status = "PASS"
        $color  = "Green"
        $pass++
    } else {
        $status = "FAIL"
        $color  = "Red"
        $fail++
    }
    $txChar = if ($txByte -ge 32 -and $txByte -le 126) { [char]$txByte } else { "." }
    $rxChar = if ($rxByte -ne $null -and $rxByte -ge 32 -and $rxByte -le 126) { [char]$rxByte } else { "." }
    Write-Host ("{0,-5} {1,-10} {2,-10} {3,-10} {4,-10} {5}" -f $i, "'$txChar'($txByte)", "0x$('{0:X2}' -f $txByte)", "'$rxChar'($rxByte)", "0x$('{0:X2}' -f $rxByte)", $status) -ForegroundColor $color
    $i++
}

Write-Host ""
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ("  RESULTS — PASS: {0}  |  FAIL: {1}" -f $pass, $fail) -ForegroundColor $(if ($fail -eq 0) { "Green" } else { "Red" })
if ($fail -eq 0) {
    Write-Host "  ALL TESTS PASSED — UART Design Verified!" -ForegroundColor Green
} else {
    Write-Host "  SOME TESTS FAILED!" -ForegroundColor Red
}
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host ""

# Show frame for 0xA5
Write-Host "Frame Visualization for 0xA5 (10100101b):" -ForegroundColor Yellow
$frame = Get-UARTFrame 0xA5
Write-Host "  START | D0 | D1 | D2 | D3 | D4 | D5 | D6 | D7 | STOP"
$labels = @("  START"); for($b=0;$b -lt 8;$b++){$labels+="D$b"}; $labels+="STOP"
$vals   = $frame | ForEach-Object { "  $_   " }
Write-Host ("  " + ($frame -join "    "))
Write-Host "  " -NoNewline
$frame | ForEach-Object { $c = if ($_ -eq 0) { "Cyan" } else { "Yellow" }; Write-Host "  $_  " -NoNewline -ForegroundColor $c }
Write-Host ""
Write-Host ""
Write-Host "  Bit Legend: 0 = LOW (blue)   1 = HIGH (yellow)" -ForegroundColor White
