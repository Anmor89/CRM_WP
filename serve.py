# -*- coding: utf-8 -*-
"""
West Part CRM — локальный сервер с авто-синхронизацией данных 1С.

Запускается через start_crm.ps1 (или напрямую: python serve.py).
Дополнительно к статике обслуживает POST /api/sync — копирует свежие xlsx
из соседней папки «Claude code/Данные 1С» в локальную _data/.

CRM (index.html) дёргает /api/sync при клике на кнопку «🔄 Обновить»,
чтобы получить актуальные файлы без перезапуска скрипта.
"""

import http.server
import io
import json
import os
import shutil
import socketserver
import sys
from pathlib import Path

# Windows-консоль обычно cp1251 — переключаем stdout/stderr на UTF-8, иначе emoji ломаются
try:
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.stderr.reconfigure(encoding='utf-8', errors='replace')
except Exception:
    pass

PORT = 8765
HERE = Path(__file__).resolve().parent
SOURCE = (HERE.parent / 'Claude code' / 'Данные 1С').resolve()
DEST = HERE / '_data'


def sync_from_yandex():
    """Удаляет старые xlsx из _data/ и копирует свежие из Yandex Disk."""
    if not SOURCE.exists():
        return {'ok': False, 'error': f'Папка не найдена: {SOURCE}'}
    DEST.mkdir(exist_ok=True)
    # Чистим старое
    for f in DEST.glob('*.xlsx'):
        try:
            f.unlink()
        except Exception:
            pass
    copied = []
    for f in SOURCE.glob('*.xlsx'):
        if f.name.startswith('~$'):
            continue  # Excel lock-файл
        target = DEST / f.name
        try:
            shutil.copy2(f, target)
            copied.append({'name': f.name, 'size': target.stat().st_size})
        except Exception as e:
            return {'ok': False, 'error': f'Не удалось скопировать {f.name}: {e}'}
    return {'ok': True, 'count': len(copied), 'copied': copied,
            'source': str(SOURCE), 'dest': str(DEST)}


class CrmHandler(http.server.SimpleHTTPRequestHandler):
    # Сервер обслуживает файлы из директории скрипта
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(HERE), **kwargs)

    def end_headers(self):
        # Чтобы fetch() из браузера не упирался в кэш
        self.send_header('Cache-Control', 'no-cache')
        super().end_headers()

    def do_POST(self):
        if self.path == '/api/sync':
            try:
                result = sync_from_yandex()
                payload = json.dumps(result, ensure_ascii=False).encode('utf-8')
                status = 200 if result.get('ok') else 500
                self.send_response(status)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.send_header('Content-Length', str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
            except Exception as e:
                err = json.dumps({'ok': False, 'error': str(e)}, ensure_ascii=False).encode('utf-8')
                self.send_response(500)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.end_headers()
                self.wfile.write(err)
        else:
            self.send_error(404)

    def log_message(self, format, *args):
        # Без болтливого лога — оставим только ошибки/sync
        msg = format % args
        if '/api/sync' in msg or ' 5' in msg or ' 4' in msg.split()[0:1] + ['']:
            sys.stderr.write(f'[CRM] {msg}\n')


class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True


def main():
    print(f'')
    print(f'  West Part CRM — локальный сервер')
    print(f'  ===================================')
    print(f'  📁 Источник 1С: {SOURCE}')
    print(f'  📁 Локальная копия: {DEST}')
    print(f'  🌐 CRM: http://localhost:{PORT}/index.html')
    print(f'  🔄 Sync endpoint: POST http://localhost:{PORT}/api/sync')
    print(f'')
    print(f'  Ctrl+C — остановить.')
    print(f'')
    with ReusableTCPServer(('', PORT), CrmHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print('\n  Остановлено пользователем.')


if __name__ == '__main__':
    main()
