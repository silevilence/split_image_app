<#
.SYNOPSIS
    SmartGridSlicer 版本检查脚本
.DESCRIPTION
    在发布前验证版本号的有效性和一致性
.PARAMETER NewVersion
    要发布的新版本号 (格式: x.y.z)
.PARAMETER Force
    强制发布，跳过版本回退警告
.EXAMPLE
    .\check_version.ps1 -NewVersion "1.1.0"
.EXAMPLE
    .\check_version.ps1 -NewVersion "1.0.0" -Force
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$NewVersion,
    
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# 颜色输出函数
function Write-Success { param($msg) Write-Host "✅ $msg" -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host "⚠️ $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "❌ $msg" -ForegroundColor Red }
function Write-Info { param($msg) Write-Host "ℹ️ $msg" -ForegroundColor Cyan }

# 解析语义化版本
function Parse-SemVer {
    param([string]$version)
    
    if ($version -match '^v?(\d+)\.(\d+)\.(\d+)(-.*)?$') {
        return @{
            Major = [int]$matches[1]
            Minor = [int]$matches[2]
            Patch = [int]$matches[3]
            Prerelease = $matches[4]
            Full = "$($matches[1]).$($matches[2]).$($matches[3])"
        }
    }
    return $null
}

# 比较版本号
function Compare-Version {
    param($v1, $v2)
    
    if ($v1.Major -ne $v2.Major) { return $v1.Major - $v2.Major }
    if ($v1.Minor -ne $v2.Minor) { return $v1.Minor - $v2.Minor }
    return $v1.Patch - $v2.Patch
}

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "   SmartGridSlicer Version Checker" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

# 1. 验证新版本格式
Write-Info "检查版本号格式..."
$newVer = Parse-SemVer $NewVersion
if (-not $newVer) {
    Write-Error "无效的版本号格式: $NewVersion"
    Write-Host "   版本号必须遵循语义化版本格式: x.y.z (如 1.2.3)"
    exit 1
}
Write-Success "版本号格式有效: $($newVer.Full)"

# 2. 读取 pubspec.yaml 中的当前版本
Write-Info "读取 pubspec.yaml 版本..."
$pubspecPath = Join-Path $PSScriptRoot "..\pubspec.yaml"
if (-not (Test-Path $pubspecPath)) {
    $pubspecPath = "pubspec.yaml"
}

if (-not (Test-Path $pubspecPath)) {
    Write-Error "找不到 pubspec.yaml 文件"
    exit 1
}

$pubspecContent = Get-Content $pubspecPath -Raw
if ($pubspecContent -match 'version:\s*(\d+\.\d+\.\d+)') {
    $pubspecVersion = $matches[1]
    Write-Success "pubspec.yaml 版本: $pubspecVersion"
} else {
    Write-Error "无法从 pubspec.yaml 读取版本号"
    exit 1
}

$currentVer = Parse-SemVer $pubspecVersion

# 3. 检查版本一致性
Write-Info "检查版本一致性..."
if ($newVer.Full -ne $pubspecVersion) {
    Write-Warning "新版本 ($($newVer.Full)) 与 pubspec.yaml 版本 ($pubspecVersion) 不匹配"
    
    $response = Read-Host "是否自动更新 pubspec.yaml? (y/N)"
    if ($response -eq 'y' -or $response -eq 'Y') {
        $newContent = $pubspecContent -replace 'version:\s*\d+\.\d+\.\d+', "version: $($newVer.Full)"
        Set-Content $pubspecPath $newContent -NoNewline
        Write-Success "已更新 pubspec.yaml 版本为 $($newVer.Full)"
    } else {
        Write-Error "版本不匹配，请手动更新 pubspec.yaml"
        exit 1
    }
}

# 4. 获取 Git 最新 Tag
Write-Info "获取 Git 最新 Tag..."
try {
    $latestTag = git describe --tags --abbrev=0 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $latestTag) {
        Write-Info "未找到现有 Tag，这将是首次发布"
        $latestTag = "v0.0.0"
    }
    Write-Success "最新 Tag: $latestTag"
    $latestVer = Parse-SemVer $latestTag
} catch {
    Write-Info "无法获取 Git Tag，假设为首次发布"
    $latestVer = Parse-SemVer "0.0.0"
}

# 5. 比较版本号
Write-Info "比较版本号..."
$comparison = Compare-Version $newVer $latestVer

if ($comparison -lt 0) {
    Write-Warning "新版本 ($($newVer.Full)) 低于最新 Tag ($latestTag)!"
    
    if (-not $Force) {
        $response = Read-Host "这是一个版本回退操作。是否继续? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Error "操作已取消"
            exit 1
        }
    } else {
        Write-Warning "已使用 -Force 参数，跳过确认"
    }
} elseif ($comparison -eq 0) {
    Write-Warning "新版本 ($($newVer.Full)) 与最新 Tag ($latestTag) 相同!"
    
    if (-not $Force) {
        $response = Read-Host "这将覆盖现有版本。是否继续? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Error "操作已取消"
            exit 1
        }
    }
} else {
    Write-Success "版本号递增有效: $latestTag -> v$($newVer.Full)"
}

# 6. 检查是否有未提交的更改
Write-Info "检查 Git 状态..."
$gitStatus = git status --porcelain 2>$null
if ($gitStatus) {
    Write-Warning "存在未提交的更改:"
    $gitStatus | ForEach-Object { Write-Host "   $_" -ForegroundColor Gray }
    
    $response = Read-Host "是否继续? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Error "请先提交更改后再发布"
        exit 1
    }
}

# 7. 生成发布命令
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "   验证通过! 准备发布 v$($newVer.Full)" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

Write-Info "执行以下命令来创建发布:"
Write-Host ""
Write-Host "   git tag -a v$($newVer.Full) -m `"Release v$($newVer.Full)`"" -ForegroundColor Yellow
Write-Host "   git push origin v$($newVer.Full)" -ForegroundColor Yellow
Write-Host ""

$response = Read-Host "是否立即执行这些命令? (y/N)"
if ($response -eq 'y' -or $response -eq 'Y') {
    Write-Info "创建 Tag..."
    git tag -a "v$($newVer.Full)" -m "Release v$($newVer.Full)"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Tag 创建成功"
        
        Write-Info "推送 Tag 到远程..."
        git push origin "v$($newVer.Full)"
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Tag 推送成功! GitHub Actions 将自动开始构建。"
            Write-Host ""
            Write-Info "查看构建进度: https://github.com/silevilence/split_image_app/actions"
        } else {
            Write-Error "Tag 推送失败"
            exit 1
        }
    } else {
        Write-Error "Tag 创建失败"
        exit 1
    }
} else {
    Write-Info "已跳过自动发布。请手动执行上述命令。"
}

Write-Host ""
