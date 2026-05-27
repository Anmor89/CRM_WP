# ============================================================
#  West Part CRM — запуск с авто-импортом данных из 1С
#  Двойной клик по этому файлу:
#   1) копирует свежие xlsx-выгрузки из Yandex Disk в _data/
#   2) запускает локальный сервер на http://localhost:8765
#   3) открывает CRM в браузере (импорт случается автоматически)
# ============================================================

$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

Write-Host ""
Write-Host "  ===================================================" -ForegroundColor DarkGray
Write-Host "   West Part CRM — запуск с авто-импортом из 1С" -ForegroundColor Yellow
Write-Host "  ===================================================" -ForegroundColor DarkGray
Write-Host ""

# Где лежат файлы 1С (в соседней папке «Claude code/Данные 1С»)
$src = Resolve-Path -Path (Join-Path $PSScriptRoot '..\Claude code\Данные 1С') -ErrorAction SilentlyContinue
$dst = Join-Path $PSScriptRoot '_data'

if (-not $src -or -not (Test-Path $src)) {
    Write-Host "  ⚠  Папка «Данные 1С» не найдена по пути:" -ForegroundColor Yellow
    Write-Host "     $(Join-Path $PSScriptRoot '..\Claude code\Данные 1С')" -ForegroundColor DarkGray
    Write-Host "     CRM откроется без авто-импорта. Загрузите файлы вручную через раздел «Выгрузки»." -ForegroundColor DarkGray
    Write-Host ""
} else {
    if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }

    # Чистим _data от старого, копируем свежее. Игнорируем lock-файлы Excel вида ~$....
    Get-ChildItem $dst -Filter '*.xlsx' -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
    $files = Get-ChildItem -Path $src -Filter '*.xlsx' | Where-Object { -not $_.Name.StartsWith('~$') }
    foreach ($f in $files) {
        Copy-Item -Path $f.FullName -Destination $dst -Force
    }
    Write-Host "  ✓ Скопировано $($files.Count) файлов из «Данные 1С»" -ForegroundColor Green
    foreach ($f in $files) {
        $sizeKb = [Math]::Round($f.Length / 1024)
        Write-Host "      • $($f.Name) — $sizeKb КБ" -ForegroundColor DarkGray
    }
    Write-Host ""
}

# Проверяем Python
try {
    $pyver = python --version 2>&1
} catch {
    Write-Host "  ✗ Python не найден в PATH." -ForegroundColor Red
    Write-Host "     Установите Python с https://python.org или через winget install Python.Python.3.12" -ForegroundColor DarkGray
    Write-Host ""
    Read-Host "  Нажмите Enter для выхода"
    exit 1
}

$port = 8765
Write-Host "  🌐 Сервер: http://localhost:$port" -ForegroundColor Cyan
Write-Host "  🌐 CRM:    http://localhost:$port/index.html" -ForegroundColor Cyan
Write-Host ""
Write-Host "  В CRM кнопка «🔄 Обновить» теперь сама обновляет данные." -ForegroundColor DarkGray
Write-Host "  Ctrl+C — остановить сервер." -ForegroundColor DarkGray
Write-Host ""

# Открываем браузер через 2 секунды (пока сервер стартует)
Start-Process powershell -ArgumentList '-NoProfile', '-WindowStyle', 'Hidden', '-Command', "Start-Sleep -Seconds 2; Start-Process 'http://localhost:$port/index.html'"

# Запускаем кастомный сервер с эндпоинтом /api/sync
python "$PSScriptRoot\serve.py"
