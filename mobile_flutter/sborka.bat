@echo off
set LOGFILE=logs.txt

echo Запуск сборки... > %LOGFILE%
echo Дата: %date% %time% >> %LOGFILE%
echo. >> %LOGFILE%

:: Альтернатива tee для Windows
flutter build apk --release --target-platform android-arm64 --no-tree-shake-icons >> %LOGFILE% 2>&1
type %LOGFILE%

if errorlevel 1 (
    echo. >> %LOGFILE%
    echo ОШИБКА: Сборка завершилась с ошибкой. >> %LOGFILE%
    type %LOGFILE%
    pause
    exit /b 1
)

echo. >> %LOGFILE%
echo УСПЕХ: Сборка завершена без ошибок. >> %LOGFILE%
type %LOGFILE%
pause