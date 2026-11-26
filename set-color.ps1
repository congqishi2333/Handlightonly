param(
    [string]$Hex
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Hex)) {
    $Hex = Read-Host '输入色号（例如 #66CCFF / 66CCFF / #ABC）'
}

# 规整输入：0x66CCFF / #66CCFF / 66CCFF / #ABC 都接受
$raw = $Hex.Trim() -replace '^0x', ''
$raw = $raw.TrimStart('#')

if ($raw -match '^[0-9a-fA-F]{3}$') {
    $raw = (($raw.ToCharArray() | ForEach-Object { "$_$_" }) -join '')
}
if ($raw -notmatch '^[0-9a-fA-F]{6}$') {
    throw "色号格式不对：$Hex。请用 #RRGGBB 或 #RGB。"
}

$culture = [System.Globalization.CultureInfo]::InvariantCulture
$r = [Convert]::ToInt32($raw.Substring(0, 2), 16) / 255.0
$g = [Convert]::ToInt32($raw.Substring(2, 2), 16) / 255.0
$b = [Convert]::ToInt32($raw.Substring(4, 2), 16) / 255.0

function Format-Channel([double]$value) {
    return $value.ToString('0.00', $script:culture)
}

function Set-Macro([string]$path, [string]$name, [string]$value) {
    $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $pattern = '(?m)^(#define\s+' + $name + '\s+)[0-9.]+(\s+//.*)$'
    $matches = [regex]::Matches($text, $pattern)
    if ($matches.Count -ne 1) {
        throw "在 $path 里找到 $($matches.Count) 个 $name，预期 1 个。"
    }
    $replacement = '${1}' + $value + '${2}'
    $text = [regex]::Replace($text, $pattern, $replacement)
    [System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))
}

$repoSettings = Join-Path $PSScriptRoot 'shaders\lib\handlight_settings.glsl'
if (-not (Test-Path $repoSettings)) {
    throw "找不到 $repoSettings。请把 set-color.ps1 放在仓库根目录。"
}

$rText = Format-Channel $r
$gText = Format-Channel $g
$bText = Format-Channel $b

Set-Macro $repoSettings 'HL_TINT_R' $rText
Set-Macro $repoSettings 'HL_TINT_G' $gText
Set-Macro $repoSettings 'HL_TINT_B' $bText

Write-Host "色号 #$($raw.ToUpperInvariant()) -> R=$rText G=$gText B=$bText"
Write-Host "已写入 $repoSettings"

# 同步到已安装的光影包，并重建 jar 版本的 zip
$installedSettings = Join-Path $env:APPDATA '.minecraft\shaderpacks\HandLightOnly\shaders\lib\handlight_settings.glsl'
if (Test-Path $installedSettings) {
    Copy-Item -LiteralPath $repoSettings -Destination $installedSettings -Force
    $packDir = (Get-Item -LiteralPath $installedSettings).Directory.Parent.Parent.FullName
    $versionDir = Join-Path $env:APPDATA '.minecraft\versions\1.21.1-NeoForge\shaderpacks'
    $zipPath = Join-Path $versionDir 'HandLightOnly.zip'

    if (Test-Path $versionDir) {
        Add-Type -AssemblyName System.IO.Compression
        $tmp = Join-Path $versionDir 'HandLightOnly.new.zip'
        $fs = [System.IO.File]::Create($tmp)
        $zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
        Get-ChildItem $packDir -Recurse -Directory | ForEach-Object {
            [void]$zip.CreateEntry($_.FullName.Substring($packDir.Length + 1).Replace('\', '/') + '/')
        }
        Get-ChildItem $packDir -Recurse -File | ForEach-Object {
            $entry = $zip.CreateEntry($_.FullName.Substring($packDir.Length + 1).Replace('\', '/'), [System.IO.Compression.CompressionLevel]::Optimal)
            $stream = $entry.Open()
            $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Dispose()
        }
        $zip.Dispose()
        $fs.Dispose()
        Move-Item -LiteralPath $tmp -Destination $zipPath -Force
        Write-Host "已同步到 $packDir 和 $zipPath"
    } else {
        Write-Host "已同步到 $packDir（没找到版本目录，跳过 zip）"
    }
} else {
    Write-Host '没找到已安装的光影包，只改了仓库文件。'
}

Write-Host ''
Write-Host '进游戏按 R 重载。如果 Shader Pack Settings 里手动改过 RGB 滑块，请先点 Reset / 重新选择光影，否则滑块值仍会覆盖这里的默认值。'
