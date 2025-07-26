
@echo off

setlocal

set GAME_NAME=StellarAssault

set BUILD_DIR=build

set DIST_DIR=dist\windows



if not exist %BUILD_DIR% mkdir %BUILD_DIR%



REM Build .love archive using PowerShell

powershell -Command "Compress-Archive -Path 'main.lua','assets','src','states' -DestinationPath '%BUILD_DIR%\stellar-assault.love' -Force"



if not exist %DIST_DIR% mkdir %DIST_DIR%

copy /Y %BUILD_DIR%\stellar-assault.love %DIST_DIR%\game.love >NUL

if exist %DIST_DIR%\love.exe ren %DIST_DIR%\love.exe %GAME_NAME%.exe

endlocal

