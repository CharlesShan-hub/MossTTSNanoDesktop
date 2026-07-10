# MOSS-TTS-Nano API 测试脚本
# 用法:
#   .\test_api.ps1                              # 测试健康检查
#   .\test_api.ps1 -Text "你好世界"               # 合成语音
#   .\test_api.ps1 -Text "hello" -Voice en_1     # 指定音色
#   .\test_api.ps1 -Health                       # 只检查健康
#   .\test_api.ps1 -Voices                       # 列出音色

param(
  [string]$Text = "",
  [string]$Voice = "yumi",
  [int]$Port = 8080,
  [switch]$Health,
  [switch]$Voices,
  [string]$OutputFile = "output.wav"
)

$base = "http://localhost:$Port"

if ($Health -or ($Text -eq "" -and -not $Voices)) {
  Write-Host "🔍 健康检查 GET $base/v1/health" -ForegroundColor Cyan
  try {
    $r = Invoke-RestMethod -Uri "$base/v1/health" -Method Get
    Write-Host "  状态: $($r.status)" -ForegroundColor Green
    Write-Host "  模型: $($r.model)" -ForegroundColor Green
  } catch {
    Write-Host "  ❌ 连接失败: $_" -ForegroundColor Red
  }
  if (-not $Voices) { exit }
}

if ($Voices) {
  Write-Host "`n🎤 音色列表 GET $base/v1/voices" -ForegroundColor Cyan
  try {
    $wc = [System.Net.WebClient]::new()
    $raw = $wc.DownloadString("$base/v1/voices")
    $wc.Dispose()
    $voices = $raw | ConvertFrom-Json
    foreach ($v in $voices) {
      Write-Host "  - $($v.name) [$($v.language)] id=$($v.id)" -ForegroundColor Yellow
    }
  } catch {
    Write-Host "  ❌ 获取失败: $_" -ForegroundColor Red
  }
  if ($Text -eq "") { exit }
}

Write-Host "`n🗣 合成语音 POST $base/v1/tts" -ForegroundColor Cyan
Write-Host "  文本: $Text" -ForegroundColor Gray
Write-Host "  音色: $Voice" -ForegroundColor Gray
Write-Host "  输出: $OutputFile" -ForegroundColor Gray

$body = @{
  text     = $Text
  voice_id = $Voice
} | ConvertTo-Json

try {
  # 使用 .NET WebClient 避免 PowerShell 对二进制数据的转码
  $wc = [System.Net.WebClient]::new()
  $wc.Headers.Add("Content-Type", "application/json")
  $utf8Body = [System.Text.Encoding]::UTF8.GetBytes($body)
  $wc.UploadData("$base/v1/tts", "POST", $utf8Body) | Set-Content -Path $OutputFile -Encoding Byte
  $wc.Dispose()
  $size = (Get-Item $OutputFile).Length
  Write-Host "  ✅ 保存成功: ${OutputFile} (${size} bytes)" -ForegroundColor Green
} catch {
  Write-Host "  ❌ 合成失败: $_" -ForegroundColor Red
}
