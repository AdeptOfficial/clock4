# PowerShell equivalent of qspi/fw-crc.sh
# Appends the CRC32 (CRC-32/ISO-HDLC, big endian byte order) of the input to a copy of it.
#   .\fw-crc.ps1 ..\mk4-time\Release\mk4-time.bin output\fwt.bin

param(
  [Parameter(Mandatory=$true)][string]$InputFile,
  [Parameter(Mandatory=$true)][string]$OutputFile
)

$ErrorActionPreference = 'Stop'

# Int64 arithmetic throughout: PowerShell parses 0xEDB88320 as a negative Int32
function Get-Crc32Table {
  $table = New-Object 'System.Int64[]' 256
  $poly = 0xEDB88320L
  for ($i = 0; $i -lt 256; $i++) {
    $c = [int64]$i
    for ($k = 0; $k -lt 8; $k++) {
      if ($c -band 1) { $c = ($poly -bxor ($c -shr 1)) -band 0xFFFFFFFFL }
      else            { $c = ($c -shr 1) -band 0xFFFFFFFFL }
    }
    $table[$i] = $c
  }
  ,$table   # comma operator, otherwise PowerShell unrolls the array
}

function Get-Crc32([byte[]]$bytes, [int64[]]$table) {
  $crc = 0xFFFFFFFFL
  foreach ($b in $bytes) {
    $crc = ($table[[int](($crc -bxor $b) -band 0xFF)] -bxor ($crc -shr 8)) -band 0xFFFFFFFFL
  }
  return ($crc -bxor 0xFFFFFFFFL) -band 0xFFFFFFFFL
}

$table = Get-Crc32Table

# self test, same check value the shell script asserts
$check = Get-Crc32 ([System.Text.Encoding]::ASCII.GetBytes("123456789")) $table
if ($check -ne 0xCBF43926L) { throw ("CRC error: self test gave {0:x8}, expected cbf43926" -f $check) }

# absolute paths throughout: .NET resolves relative paths against the process
# directory, which is not where Set-Location points
$in = (Resolve-Path -LiteralPath $InputFile).Path
$out = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PWD.Path, $OutputFile))

$bytes = [System.IO.File]::ReadAllBytes($in)
$crc = Get-Crc32 $bytes $table

# big endian, matching  crc32 file | xxd -r -p
# each element fully parenthesised: the comma binds tighter than -band
$crcBytes = [byte[]]@(
  ((($crc -shr 24) -band 0xFF)),
  ((($crc -shr 16) -band 0xFF)),
  ((($crc -shr  8) -band 0xFF)),
  (( $crc          -band 0xFF))
)

$outDir = Split-Path -Parent $out
if ($outDir -and -not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

[System.IO.File]::WriteAllBytes($out, ($bytes + $crcBytes))

$size = (Get-Item $out).Length
Write-Host ("Created {0}  crc {1:x8}  {2} bytes" -f $out, $crc, $size)
if ($size -ne 196608) {
  Write-Warning "fwt.bin should be exactly 196608 bytes (192K). Check that you built the Release configuration."
}
