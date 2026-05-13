@echo off
setlocal

REM ==========================================
REM Build HTML resource file for Delphi
REM ==========================================

REM Input HTML file
set HTML_FILE=index.html

REM Output resource script
set RC_FILE=html.rc

REM Output compiled resource
set RES_FILE=html.res

REM Resource name
set RESOURCE_NAME=HTML_INDEX

echo Creating RC file...

echo %RESOURCE_NAME% RCDATA "%HTML_FILE%" > %RC_FILE%

echo Compiling resource...

REM Adjust path if brcc32.exe is not in PATH
brcc32 %RC_FILE%

if exist %RES_FILE% (
    echo.
    echo Resource generated successfully: %RES_FILE%
) else (
    echo.
    echo Failed to generate resource.
)

pause