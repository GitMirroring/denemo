@ECHO OFF
cd /D %~dp0

@echo off

REM ------------------------------------------------------------------------------
REM Fix Guile .go file timestamps on first run (or after unzip timestamp reset).
REM Windows unzip sets all files to "now", making .scm appear newer than .go.
REM Guile then tries to recompile .go files, which fails with:
REM   "Wrong number of arguments to #<boot-closure>"
REM We stamp .go files to a far-future date so Guile always trusts them.
REM This is safe - Guile only checks relative age, not absolute date.
REM ------------------------------------------------------------------------------

SET "LILY_LIB=%~dp0lilypond\lib"

REM Check if already fixed (sentinel file)
IF NOT EXIST "%~dp0.go_timestamps_fixed" (
    echo Fixing Guile .go timestamps, please wait...
    FOR /R "%LILY_LIB%" %%F IN (*.go) DO (
        copy /b "%%F"+,, "%%F" >nul 2>&1
    )
    echo. > "%~dp0.go_timestamps_fixed"
    echo Done.
)

REM Regenerate pixbuf loaders cache
if exist bin\gdk-pixbuf-query-loaders.exe (
    bin\gdk-pixbuf-query-loaders.exe lib\gdk-pixbuf-2.0\2.10.0\loaders\*.dll > lib\gdk-pixbuf-2.0\2.10.0\loaders.cache 2>nul
)

REM Regenerate GTK IM modules cache
if exist bin\gtk-query-immodules-3.0.exe (
    bin\gtk-query-immodules-3.0.exe lib\gtk-3.0\3.0.0\immodules\*.dll > lib\gtk-3.0\3.0.0\immodules.cache 2>nul
)

REM Compile GLib schemas if needed
if not exist share\glib-2.0\schemas\gschemas.compiled (
    bin\glib-compile-schemas.exe share\glib-2.0\schemas
)

REM Guile settings
set GUILE_LOAD_PATH=%~dp0share\guile\2.2
set GUILE_LOAD_COMPILED_PATH=%~dp0lib\guile\2.2\ccache
set GUILE_AUTO_COMPILE=0


REM GIO/GLib settings
set GIO_USE_VFS=local
set GSETTINGS_SCHEMA_DIR=%~dp0share\glib-2.0\schemas

REM Font configuration
set FONTCONFIG_PATH=%~dp0etc\fonts
set FONTCONFIG_FILE=%~dp0etc\fonts\fonts.conf

REM GTK settings
set XDG_DATA_DIRS=%~dp0share
set XDG_DATA_HOME=%~dp0share
set GTK_DATA_PREFIX=%~dp065;11M65;11m

set GTK_EXE_PREFIX=%~dp0

REM Path
set PATH=%~dp0bin;%PATH%

REM already did this I think. cd /d "%~dp0"
set FONTCONFIG_PATH=%~dp0etc\fonts
set FC_CACHEDIR=%~dp0fontconfig\cache

if not exist fontconfig\cache mkdir fontconfig\cache

if not exist fontconfig\cache\* (
    bin\fc-cache.exe -fv share\fonts
)

bin\regfont.exe -a share\fonts\truetype\denemo\feta.ttf
bin\regfont.exe -a share\fonts\truetype\denemo\Denemo.ttf
bin\regfont.exe -a share\fonts\truetype\denemo\emmentaler.ttf

set EVINCE_BACKENDS_DIR=%~dp0lib\evince\4\backends
set GI_TYPELIB_PATH=%~dp0lib\girepository-1.0

REM mime database
bin\update-mime-database.exe share\mime

echo Environment ready, launching Denemo...
echo GUILE_LOAD_PATH=%GUILE_LOAD_PATH%
echo GUILE_LOAD_COMPILED_PATH=%GUILE_LOAD_COMPILED_PATH%

set DBUS_SESSION_BUS_ADDRESS=disabled
set NO_AT_BRIDGE=1
bin\denemo.exe %*

IF %ERRORLEVEL% NEQ 0 (
    echo Denemo exited with code %ERRORLEVEL%
    pause
)
