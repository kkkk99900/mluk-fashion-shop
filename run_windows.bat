@echo off
chcp 65001 >nul
cd /d "%~dp0"
if not exist ".env" (
    echo [LỖI] Chưa có file .env. Hãy sao chép .env.example thành .env rồi điền SQL_SERVER.
    pause
    exit /b 1
)
python app.py
pause
