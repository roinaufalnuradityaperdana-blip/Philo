@echo off
echo ========================================================
echo  Suoro - Build Android .apk
echo ========================================================
echo.

where flutter >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Flutter SDK belum terinstall di komputer ini.
    echo Silakan install Flutter dari: https://flutter.dev
    echo atau gunakan GitHub Actions untuk download file .apk otomatis.
    pause
    exit /b 1
)

echo [1/3] Mengambil dependencies...
call flutter pub get

echo [2/3] Membangun Suoro Android release (.apk)...
call flutter build apk --release

if %errorlevel% neq 0 (
    echo [ERROR] Build Android APK gagal.
    pause
    exit /b 1
)

echo [3/3] Menyiapkan folder output...
if not exist "dist" mkdir dist
copy /y "build\app\outputs\flutter-apk\app-release.apk" "dist\Suoro.apk" >nul

echo.
echo ========================================================
echo  SELESAI! File instalasi Android siap di:
echo  dist\Suoro.apk
echo ========================================================
pause
