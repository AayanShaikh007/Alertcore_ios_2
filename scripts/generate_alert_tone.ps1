$ErrorActionPreference = 'Stop'

$path = 'C:\coding\alertcore_ios\AlertCoreApp\Resources\AlertCoreTone.wav'
$sampleRate = 44100
$durationSeconds = 10
$totalSamples = $sampleRate * $durationSeconds

$pcm = New-Object System.Collections.Generic.List[byte]

for ($sampleIndex = 0; $sampleIndex -lt $totalSamples; $sampleIndex++) {
    $progress = $sampleIndex / [double]$sampleRate
    $tonePhase = $progress % 1.0
    $isTone = ($tonePhase -lt 0.35) -or (($tonePhase -ge 0.5) -and ($tonePhase -lt 0.85))
    $fadeWindow = 0.02

    if ($tonePhase -lt $fadeWindow) { $envelope = $tonePhase / $fadeWindow }
    elseif ($tonePhase -lt 0.35 - $fadeWindow) { $envelope = 1.0 }
    elseif ($tonePhase -lt 0.35) { $envelope = [Math]::Max(0.0, (0.35 - $tonePhase) / $fadeWindow) }
    elseif ($tonePhase -lt 0.5) { $envelope = 0.0 }
    elseif ($tonePhase -lt 0.5 + $fadeWindow) { $envelope = ($tonePhase - 0.5) / $fadeWindow }
    elseif ($tonePhase -lt 0.85 - $fadeWindow) { $envelope = 1.0 }
    elseif ($tonePhase -lt 0.85) { $envelope = [Math]::Max(0.0, (0.85 - $tonePhase) / $fadeWindow) }
    else { $envelope = 0.0 }

    $amplitude = if ($isTone) { 0.45 * $envelope } else { 0.0 }
    $frequency = 880.0
    $sample = [int16]([Math]::Sin(2.0 * [Math]::PI * $frequency * $progress) * $amplitude * [int16]::MaxValue)
    $pcm.AddRange([BitConverter]::GetBytes($sample))
}

function Write-Ascii([System.IO.BinaryWriter]$bw, [string]$s) {
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes($s))
}

$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)

Write-Ascii $bw 'RIFF'
$subchunk2Size = [uint32]$pcm.Count
$chunkSize = [uint32](36 + $subchunk2Size)
$bw.Write($chunkSize)
Write-Ascii $bw 'WAVE'
Write-Ascii $bw 'fmt '
$bw.Write([uint32]16)
$bw.Write([uint16]1)
$bw.Write([uint16]1)
$bw.Write([uint32]$sampleRate)
$bw.Write([uint32]($sampleRate * 2))
$bw.Write([uint16]2)
$bw.Write([uint16]16)
Write-Ascii $bw 'data'
$bw.Write($subchunk2Size)
$bw.Write($pcm.ToArray())
$bw.Flush()

[System.IO.Directory]::CreateDirectory((Split-Path $path)) | Out-Null
[System.IO.File]::WriteAllBytes($path, $ms.ToArray())
Write-Output $path
