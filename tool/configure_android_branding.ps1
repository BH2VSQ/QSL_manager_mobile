$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$android = Join-Path $root 'android'
$app = Join-Path $android 'app'
$res = Join-Path $app 'src\main\res'
$brandingRes = Join-Path $PSScriptRoot 'android_branding\res'
if (-not (Test-Path $app)) {
  throw "未找到 android/app。请先执行: flutter create . --platforms=android"
}

$targetId = 'cn.bh2vsq.qslmanager'
$targetName = 'QSLMM'

$gradleKts = Join-Path $app 'build.gradle.kts'
$gradleGroovy = Join-Path $app 'build.gradle'
$gradle = $null
$isKts = $false
if (Test-Path $gradleKts) { $gradle = $gradleKts; $isKts = $true }
elseif (Test-Path $gradleGroovy) { $gradle = $gradleGroovy }
else { throw '未找到 android/app/build.gradle(.kts)' }

$g = Get-Content $gradle -Raw -Encoding UTF8
if ($isKts) {
  if ($g -match '(?m)^\s*namespace\s*=\s*"[^"]+"') {
    $g = [regex]::Replace($g, '(?m)^\s*namespace\s*=\s*"[^"]+"', "    namespace = `"$targetId`"")
  } else {
    $g = $g -replace '(?m)^android\s*\{', "android {`r`n    namespace = `"$targetId`""
  }
  if ($g -match '(?m)^\s*applicationId\s*=\s*"[^"]+"') {
    $g = [regex]::Replace($g, '(?m)^\s*applicationId\s*=\s*"[^"]+"', "        applicationId = `"$targetId`"")
  } else {
    throw '未找到 defaultConfig.applicationId，请手动设置为 cn.bh2vsq.qslmanager'
  }
} else {
  if ($g -match "(?m)^\s*namespace\s+['\"][^'\"]+['\"]") {
    $g = [regex]::Replace($g, "(?m)^\s*namespace\s+['\"][^'\"]+['\"]", "    namespace '$targetId'")
  }
  if ($g -match "(?m)^\s*applicationId\s+['\"][^'\"]+['\"]") {
    $g = [regex]::Replace($g, "(?m)^\s*applicationId\s+['\"][^'\"]+['\"]", "        applicationId '$targetId'")
  } else {
    throw '未找到 defaultConfig.applicationId，请手动设置为 cn.bh2vsq.qslmanager'
  }
}
Set-Content $gradle $g -Encoding UTF8

$manifest = Join-Path $app 'src\main\AndroidManifest.xml'
if (Test-Path $manifest) {
  $m = Get-Content $manifest -Raw -Encoding UTF8
  if ($m -match 'android:label="[^"]*"') {
    $m = [regex]::Replace($m, 'android:label="[^"]*"', 'android:label="@string/app_name"', 1)
  } else {
    $m = $m -replace '<application\b', '<application android:label="@string/app_name"', 1
  }
  if ($m -match 'android:icon="[^"]*"') {
    $m = [regex]::Replace($m, 'android:icon="[^"]*"', 'android:icon="@mipmap/ic_launcher"', 1)
  } else {
    $m = $m -replace '<application\b', '<application android:icon="@mipmap/ic_launcher"', 1
  }
  Set-Content $manifest $m -Encoding UTF8
}

# Keep MainActivity package declaration and directory aligned with the Android application id.
$mainActivity = Get-ChildItem (Join-Path $app 'src\main') -Recurse -File | Where-Object { $_.Name -match '^MainActivity\.(kt|java)$' } | Select-Object -First 1
if ($mainActivity) {
  $content = Get-Content $mainActivity.FullName -Raw -Encoding UTF8
  if ($content -match '(?m)^package\s+[^\r\n]+') {
    $content = [regex]::Replace($content, '(?m)^package\s+[^\r\n]+', "package $targetId", 1)
  } else {
    $content = "package $targetId`r`n`r`n$content"
  }
  $newDir = Join-Path $app ('src\main\' + ($targetId -replace '\.', '\'))
  New-Item -ItemType Directory -Force -Path $newDir | Out-Null
  $newPath = Join-Path $newDir $mainActivity.Name
  Set-Content $newPath $content -Encoding UTF8
  if ($mainActivity.FullName -ne $newPath) { Remove-Item $mainActivity.FullName -Force }
}

# Install the shipped launcher resources. No icon-generation command is required.
if (-not (Test-Path $brandingRes)) { throw "缺少 Android 图标资源：$brandingRes" }
New-Item -ItemType Directory -Force -Path $res | Out-Null
Copy-Item (Join-Path $brandingRes '*') $res -Recurse -Force

Write-Host ''
Write-Host 'QSLMM Android 品牌配置完成:'
Write-Host "  Application ID: $targetId"
Write-Host '  Android App Name: QSLMM'
Write-Host '  Launcher Icon:    installed from assets/icon/qslmm_icon.png'
Write-Host '  Flutter UI title: unchanged'
