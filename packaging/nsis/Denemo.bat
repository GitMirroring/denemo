@ECHO OFF
cd /D %~dp0
@echo off

set LANG=en_US.UTF-8
set LC_ALL=en_US.UTF-8

REM Detect if running under Wine
reg query "HKLM\Software\Wine" >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    SET GUILE_JIT_THRESHOLD=-1
    ECHO Running under Wine - JIT disabled for compatibility
)

REM Fix Guile .go file timestamps on first run (or after unzip timestamp reset).
IF NOT EXIST "%~dp0.go_timestamps_fixed" (
    echo Fixing Guile .go timestamps, please wait...
    FOR /R "%~dp0lib\guile" %%F IN (*.go) DO (
        copy /b "%%F"+,, "%%F" >nul 2>&1
    )
    FOR /R "%~dp0lilypond\lib" %%F IN (*.go) DO (
        copy /b "%%F"+,, "%%F" >nul 2>&1
    )
    echo. > "%~dp0.go_timestamps_fixed"
    echo Done.
)

REM Regenerate pixbuf loaders cache once
IF NOT EXIST "%~dp0.pixbuf_cache_built" (
    if exist bin\gdk-pixbuf-query-loaders.exe (
        bin\gdk-pixbuf-query-loaders.exe lib\gdk-pixbuf-2.0\2.10.0\loaders\*.dll > lib\gdk-pixbuf-2.0\2.10.0\loaders.cache 2>nul
        echo. > "%~dp0.pixbuf_cache_built"
    )
)

REM Regenerate GTK IM modules cache once
IF NOT EXIST "%~dp0.immodules_cache_built" (
    if exist bin\gtk-query-immodules-3.0.exe (
        bin\gtk-query-immodules-3.0.exe lib\gtk-3.0\3.0.0\immodules\*.dll > lib\gtk-3.0\3.0.0\immodules.cache 2>nul
        echo. > "%~dp0.immodules_cache_built"
    )
)

REM Compile GLib schemas once
if not exist share\glib-2.0\schemas\gschemas.compiled (
    bin\glib-compile-schemas.exe share\glib-2.0\schemas
)

REM Guile settings
set GUILE_LOAD_PATH=%~dp0share\guile\3.0
set GUILE_LOAD_COMPILED_PATH=%APPDATA%\Denemo\guile\3.0\ccache
if not exist "%GUILE_LOAD_COMPILED_PATH%" mkdir "%GUILE_LOAD_COMPILED_PATH%"
set GUILE_AUTO_COMPILE=0

REM GIO/GLib settings
set GIO_USE_VFS=local
set GSETTINGS_SCHEMA_DIR=%~dp0share\glib-2.0\schemas
set GIO_MODULE_DIR=%~dp0lib\gio\modules
set GIO_USE_FILE_DATABASE=0

REM Font configuration
set FONTCONFIG_PATH=%~dp0etc\fonts
set FONTCONFIG_FILE=%~dp0etc\fonts\fonts.conf

REM GTK settings
set XDG_DATA_DIRS=%~dp0share
set XDG_DATA_HOME=%~dp0share
set GTK_DATA_PREFIX=%~dp0
set GTK_EXE_PREFIX=%~dp0

REM Path
set PATH=%~dp0bin;%PATH%

REM Font cache once
set FONTCONFIG_PATH=%~dp0etc\fonts
set FC_CACHEDIR=%~dp0fontconfig\cache
if not exist fontconfig\cache mkdir fontconfig\cache
IF NOT EXIST "%~dp0.fontconfig_cache_built" (
    bin\fc-cache.exe -fv share\fonts
    echo. > "%~dp0.fontconfig_cache_built"
)

REM Register fonts once
IF NOT EXIST "%~dp0.fonts_registered" (
    bin\regfont.exe -a share\fonts\truetype\denemo\feta.ttf
    bin\regfont.exe -a share\fonts\truetype\denemo\Denemo.ttf
    bin\regfont.exe -a share\fonts\truetype\denemo\emmentaler.ttf
    echo. > "%~dp0.fonts_registered"
)

REM Mime database once
IF NOT EXIST "%~dp0.mime_db_built" (
    if exist bin\update-mime-database.exe bin\update-mime-database.exe share\mime
    echo. > "%~dp0.mime_db_built"
)

set EVINCE_BACKENDS_DIR=%~dp0lib\evince\4\backends
set GI_TYPELIB_PATH=%~dp0lib\girepository-1.0
set DBUS_SESSION_BUS_ADDRESS=disabled
set NO_AT_BRIDGE=1

echo Environment ready, launching Denemo...
echo GUILE_LOAD_PATH=%GUILE_LOAD_PATH%
echo GUILE_LOAD_COMPILED_PATH=%GUILE_LOAD_COMPILED_PATH%

bin\denemo.exe %*
IF %ERRORLEVEL% NEQ 0 (
    echo Denemo exited with code %ERRORLEVEL%
    pause
)
