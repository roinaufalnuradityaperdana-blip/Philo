@echo off
echo ========================================================
echo  Suoro - Build Windows .exe
echo ========================================================
echo.

where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Flutter SDK belum terinstall di komputer ini.
    echo Silakan install Flutter dari: https://flutter.dev
    echo atau gunakan GitHub Actions untuk download file .exe otomatis.
    pause
    exit /b 1
)

echo [1/3] Mengambil dependencies...
call flutter pub get

echo [2/3] Membangun Suoro Windows release (.exe)...
call flutter build windows --release

if %errorlevel% neq 0 (
    echo [ERROR] Build Windows gagal.
    pause
    exit /b 1
)

echo [3/3] Menyiapkan folder output...
if not exist "dist" mkdir dist
copy /y "build\windows\x64\runner\Release\suoro.exe" "dist\Suoro.exe" >nul

echo.
echo ========================================================
echo  SELESAI! File executable siap di:
echo  dist\Suoro.exe
echo ========================================================
pause
