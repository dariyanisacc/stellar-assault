@echo off
REM Build script for Stellar Assault on Windows
REM Creates .love file and Windows executable

set GAME_NAME=StellarAssault
set VERSION=1.2.0
set LOVE_VERSION=11.5
set BUILD_DIR=build
set DIST_DIR=dist

echo Building %GAME_NAME% v%VERSION%...

REM Create build directories
if not exist %BUILD_DIR% mkdir %BUILD_DIR%
if not exist %DIST_DIR% mkdir %DIST_DIR%
if not exist %DIST_DIR%\windows mkdir %DIST_DIR%\windows

REM Clean previous builds
del /Q %BUILD_DIR%\*.love 2>nul
del /Q %DIST_DIR%\windows\*.exe 2>nul

REM Create .love file
echo Creating .love file...
cd /d "%~dp0"

REM Create file list
echo Creating file list...
dir /B *.lua > filelist.txt
dir /B /S src\*.lua >> filelist.txt
dir /B /S states\*.lua >> filelist.txt
dir /B /S assets\*.* >> filelist.txt
dir /B *.mp3 *.wav *.ogg *.flac 2>nul >> filelist.txt
echo conf.lua >> filelist.txt
echo README.md >> filelist.txt

REM Use 7-Zip if available, otherwise use PowerShell
where 7z >nul 2>nul
if %errorlevel% equ 0 (
    echo Using 7-Zip...
    7z a -tzip "%BUILD_DIR%\%GAME_NAME%.love" @filelist.txt -x!.git -x!build -x!dist -x!tests -x!*.love
) else (
    echo Using PowerShell...
    powershell -command "Get-Content filelist.txt | ForEach-Object { $_ } | Compress-Archive -DestinationPath '%BUILD_DIR%\%GAME_NAME%.zip' -Force"
    move /Y "%BUILD_DIR%\%GAME_NAME%.zip" "%BUILD_DIR%\%GAME_NAME%.love"
)

REM Clean up
del filelist.txt

if exist "%BUILD_DIR%\%GAME_NAME%.love" (
    echo [OK] .love file created: %BUILD_DIR%\%GAME_NAME%.love
) else (
    echo [ERROR] Failed to create .love file
    goto :error
)

REM Check if Love2D is in dist/windows
if exist "%DIST_DIR%\windows\love.exe" (
    echo Creating Windows executable...
    copy /b "%DIST_DIR%\windows\love.exe"+"%BUILD_DIR%\%GAME_NAME%.love" "%DIST_DIR%\windows\%GAME_NAME%.exe"
    
    if exist "%DIST_DIR%\windows\%GAME_NAME%.exe" (
        echo [OK] Windows executable created: %DIST_DIR%\windows\%GAME_NAME%.exe
        
        REM Create batch launcher
        echo @echo off > "%DIST_DIR%\windows\run_%GAME_NAME%.bat"
        echo cd /d "%%~dp0" >> "%DIST_DIR%\windows\run_%GAME_NAME%.bat"
        echo start "" "%GAME_NAME%.exe" >> "%DIST_DIR%\windows\run_%GAME_NAME%.bat"
        
        echo [OK] Launcher created: %DIST_DIR%\windows\run_%GAME_NAME%.bat
    ) else (
        echo [ERROR] Failed to create executable
    )
) else (
    echo.
    echo Love2D not found in %DIST_DIR%\windows\
    echo.
    echo To create Windows executable:
    echo 1. Download Love2D %LOVE_VERSION% for Windows (64-bit) from:
    echo    https://github.com/love2d/love/releases/download/%LOVE_VERSION%/love-%LOVE_VERSION%-win64.zip
    echo 2. Extract ALL files (love.exe and all DLLs) to %DIST_DIR%\windows\
    echo 3. Run this script again
    echo.
    echo Alternatively, users can run the .love file directly if Love2D is installed.
)

REM Create README for distribution
echo Creating distribution README...
(
echo Stellar Assault v%VERSION%
echo =======================
echo.
echo A space shooter game made with Love2D.
echo.
echo Running the Game:
echo ----------------
echo Option 1: Double-click %GAME_NAME%.exe
echo Option 2: Run the .love file with Love2D installed
echo Option 3: Use run_%GAME_NAME%.bat
echo.
echo Controls:
echo ---------
echo Arrow Keys / WASD - Move
echo Space - Shoot
echo B - Use Bomb
echo P - Pause
echo ESC - Menu
echo.
echo System Requirements:
echo -------------------
echo - Windows 7 or later
echo - OpenGL 2.1 support
echo - 100MB free disk space
echo.
echo If the game doesn't start, install Visual C++ Redistributable:
echo https://aka.ms/vs/17/release/vc_redist.x64.exe
echo.
) > "%DIST_DIR%\windows\README.txt"

echo.
echo Build Summary:
echo ==============
echo Version: %VERSION%
echo Love file: %BUILD_DIR%\%GAME_NAME%.love
echo.
echo To test the .love file:
echo   love %BUILD_DIR%\%GAME_NAME%.love
echo.
echo Build complete!
goto :end

:error
echo Build failed!
exit /b 1

:end
pause