# ==========================================================
#   West Part CRM — публикация актуальной версии в интернет
#   Запуск: правый клик по файлу -> "Выполнить с помощью PowerShell"
#   (или в PowerShell:  .\deploy.ps1 )
# ==========================================================

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

Write-Host ""
Write-Host "  ===========================================" -ForegroundColor DarkGray
Write-Host "   West Part CRM - публикация обновления" -ForegroundColor Yellow
Write-Host "  ===========================================" -ForegroundColor DarkGray
Write-Host ""

# Проверка: репозиторий уже настроен?
if (-not (Test-Path ".git")) {
    Write-Host "  Репозиторий ещё не настроен." -ForegroundColor Red
    Write-Host "  Откройте файл 'ИНСТРУКЦИЯ-git-деплой.md' и выполните разовую настройку." -ForegroundColor Red
    Write-Host ""
    Read-Host "  Нажмите Enter для выхода"
    exit 1
}

# Есть ли вообще изменения
$changes = git status --porcelain
if ([string]::IsNullOrWhiteSpace($changes)) {
    Write-Host "  Изменений нет — публиковать нечего." -ForegroundColor Cyan
    Write-Host ""
    Read-Host "  Нажмите Enter для выхода"
    exit 0
}

# Сообщение к коммиту
$msg = Read-Host "  Кратко опишите изменения (или просто Enter)"
if ([string]::IsNullOrWhiteSpace($msg)) {
    $msg = "Обновление " + (Get-Date -Format "yyyy-MM-dd HH:mm")
}

Write-Host ""
Write-Host "  Публикую..." -ForegroundColor DarkGray

git add -A
git commit -m $msg
git push

Write-Host ""
Write-Host "  Готово. Сайт обновится в течение 1-2 минут." -ForegroundColor Green
Write-Host ""
Read-Host "  Нажмите Enter для выхода"
