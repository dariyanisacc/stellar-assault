@echo off
echo Starting Stellar Assault...
echo.
echo Make sure Love2D is installed and in your PATH.
echo If not, replace 'love' with the full path to love.exe
echo.

REM Run Love2D on the current directory
love "%~dp0"

pause