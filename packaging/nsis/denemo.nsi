;;;; denemo.nsi -- Denemo installer script for Microsoft Windows
;;;; Based on original by Jan Nieuwenhuizen and Han-Wen Nienhuys
;;;; Licence: GNU GPL

;;; ---------------------------------------------------------------------------
;;; Build-time defines (pass with /DNAME=value on the makensis command line)
;;;
;;;   makensis /DVERSION=2.7.0 /DROOT=../../target/mingw denemo.nsi
;;;
;;; VERSION      -- e.g. 2.7.0
;;; ROOT         -- path to the staged install tree (must contain bin/,
;;;                 share/, lib/, license/ subdirectories)
;;;
;;; Derived names (do not need to be passed in):
;;; ---------------------------------------------------------------------------
!define NAME        "denemo"
!define PRETTY_NAME "Denemo"
!define CANARY_EXE  "denemo"
!define EXE         "$INSTDIR\bin\denemo.exe"
!define BAT         "$INSTDIR\Denemo.bat"

;;; Registry keys
!define ENVIRON       "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRETTY_NAME}"
!define INSTALL_KEY   "SOFTWARE\${PRETTY_NAME}"
!define USER_SHELL_FOLDERS \
    "Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"

;;; Uninstall log - not used, kept for reference
;;; !define UninstLog "files.txt"

;;; ---------------------------------------------------------------------------
;;; Includes
;;; ---------------------------------------------------------------------------
!include "MUI2.nsh"
!include "StrFunc.nsh"
${StrLoc}
${UnStrLoc}

;;; ---------------------------------------------------------------------------
;;; General settings
;;; ---------------------------------------------------------------------------
Name                "${PRETTY_NAME} ${VERSION}"
OutFile             "${PRETTY_NAME}-${VERSION}-setup.exe"
InstallDir          "$PROGRAMFILES\${PRETTY_NAME}"
InstallDirRegKey    HKLM "${INSTALL_KEY}" "Install_Dir"

SetCompressor       /SOLID lzma
CRCCheck            on
RequestExecutionLevel admin

;;; ---------------------------------------------------------------------------
;;; Modern UI appearance
;;; ---------------------------------------------------------------------------
!define MUI_ABORTWARNING
!define MUI_ICON   "${ROOT}/share/icons/hicolor/denemo.ico"
!define MUI_UNICON "${ROOT}/share/icons/hicolor/denemo.ico"

!define MUI_WELCOMEPAGE_TITLE   "Welcome to the ${PRETTY_NAME} ${VERSION} Setup"
!define MUI_WELCOMEPAGE_TEXT    \
    "This will install ${PRETTY_NAME} ${VERSION} on your computer.$\r$\n$\r$\n\
     Denemo is a free music notation editor that uses LilyPond for \
     typesetting.$\r$\n$\r$\nClick Next to continue."

!define MUI_FINISHPAGE_RUN      "${BAT}"
!define MUI_FINISHPAGE_RUN_TEXT "Launch ${PRETTY_NAME} now"
!define MUI_FINISHPAGE_LINK     "Visit the Denemo website"
!define MUI_FINISHPAGE_LINK_LOCATION "https://www.denemo.org/"

;;; Installer pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE   "${ROOT}/license/denemo"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

;;; Uninstaller pages
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"


Function .onInit
    ReadRegStr $R0 HKLM "${INSTALL_KEY}" "Install_Dir"
    StrCmp $R0 "" done_check

    ReadRegStr $R1 HKLM "${UNINSTALL_KEY}" "DisplayVersion"
    MessageBox MB_YESNOCANCEL|MB_ICONQUESTION \
        "Denemo $R1 is already installed in '$R0'.$\n$\nClick Yes to upgrade, No to install alongside it, or Cancel to abort." \
        IDYES run_uninstaller IDNO done_check
    Abort

run_uninstaller:
    ReadRegStr $R2 HKLM "${UNINSTALL_KEY}" "UninstallString"
    ExecWait '$R2 /S _?=$R0'   ; silent uninstall, keeping $INSTDIR

done_check:
FunctionEnd

;;; ---------------------------------------------------------------------------
;;; Helper: add a directory to the system PATH (no-op if already present)
;;; ---------------------------------------------------------------------------
Function AddToPath
    ReadRegStr $R0 HKLM "${ENVIRON}" "PATH"
    ; Check if already present
    ${StrLoc} $0 $R0 "$INSTDIR\bin" >
    StrCmp $0 "" 0 already_present
    WriteRegExpandStr HKLM "${ENVIRON}" "PATH" "$R0;$INSTDIR\bin"
    ; Broadcast the change so open Explorer windows pick it up
    SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
already_present:
FunctionEnd

;;; ---------------------------------------------------------------------------
;;; Helper: remove our directory from the system PATH
;;; ---------------------------------------------------------------------------
Function un.RemoveFromPath
    ReadRegStr $R0 HKLM "${ENVIRON}" "PATH"
path_loop:
    ${UnStrLoc} $0 $R0 "$INSTDIR\bin;" >
    StrCmp $0 "" path_done
    StrLen $1 "$INSTDIR\bin;"
    IntOp $2 $0 + $1
    StrCpy $3 $R0 $0 0
    StrCpy $4 $R0 10000 $2
    WriteRegExpandStr HKLM "${ENVIRON}" "PATH" "$3$4"
    ReadRegStr $R0 HKLM "${ENVIRON}" "PATH"
    Goto path_loop
path_done:
    SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "STR:Environment" /TIMEOUT=5000
FunctionEnd

;;; ---------------------------------------------------------------------------
;;; Section: Main install (required)
;;; ---------------------------------------------------------------------------
Section "${PRETTY_NAME} (required)" SecMain
    SectionIn RO   ; cannot be deselected

    SetOverwrite on
    AllowSkipFiles on

    ; Kill any running Denemo instance before installing
    nsExec::ExecToLog 'taskkill /F /IM denemo.exe'
    Sleep 1000

    Delete "$INSTDIR\bin\denemo.exe"
    ;; Delete the exe first in case a previous install is present
    ;; (avoids "file in use" error on reinstall)
    Delete "$INSTDIR\bin\denemo.exe"

    ; --- bin ---
    SetOutPath "$INSTDIR\bin"
    File /r "${ROOT}\bin\*.*"

    ; --- Denemo.bat goes in $INSTDIR root ---
    SetOutPath "$INSTDIR"
    File /nonfatal "${ROOT}\Denemo.bat"

    ; --- etc ---
    SetOutPath "$INSTDIR\etc"
    File /r "${ROOT}\etc\*.*"

    ; --- lib ---
    SetOutPath "$INSTDIR\lib"
    File /r "${ROOT}\lib\*.*"


    ; --- share ---
    SetOutPath "$INSTDIR\share"
    File /r "${ROOT}\share\*.*"

    ; --- lilypond ---
    SetOutPath "$INSTDIR\lilypond"
    File /nonfatal /r "${ROOT}\lilypond\*.*"

    ; --- license ---
    SetOutPath "$INSTDIR\license"
    File /r "${ROOT}\license\*.*"

    WriteUninstaller "$INSTDIR\uninstall.exe"
    ; ... rest of registry writes unchanged ...

    ;; Registry: install location + Add/Remove Programs entry
    WriteRegStr   HKLM "${INSTALL_KEY}"   "Install_Dir"      "$INSTDIR"
    WriteRegStr   HKLM "${UNINSTALL_KEY}" "DisplayIcon"      "$INSTDIR\share\icons\hicolor\denemo.ico"
    WriteRegStr   HKLM "${UNINSTALL_KEY}" "DisplayName"      "${PRETTY_NAME} ${VERSION}"
    WriteRegStr   HKLM "${UNINSTALL_KEY}" "DisplayVersion"   "${VERSION}"
    WriteRegStr   HKLM "${UNINSTALL_KEY}" "Publisher"        "Denemo Development Team"
    WriteRegStr   HKLM "${UNINSTALL_KEY}" "URLInfoAbout"     "https://www.denemo.org/"
    WriteRegStr   HKLM "${UNINSTALL_KEY}" "UninstallString"  '"$INSTDIR\uninstall.exe"'
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoModify"         1
    WriteRegDWORD HKLM "${UNINSTALL_KEY}" "NoRepair"         1

    ;; Add to system PATH so denemo is usable from the command line
    Call AddToPath

    ;; LilyPond post-install (font registration etc.)
    Call postinstall_lilypond
SectionEnd

;;; ---------------------------------------------------------------------------
;;; Section: Start Menu & Desktop shortcuts (optional)
;;; ---------------------------------------------------------------------------
Section "Start Menu and Desktop Shortcuts" SecShortcuts
    ;; Try all-users first; fall back to current user if we lack permissions
    ClearErrors
    SetShellVarContext all
    SetOutPath "$INSTDIR"
    Call CreateShortcuts
    IfErrors 0 shortcuts_done

    ;; Clean up failed all-users attempt
    Delete "$DESKTOP\${PRETTY_NAME}.lnk"
    Delete "$SMPROGRAMS\${PRETTY_NAME}\*.*"
    RMDir  "$SMPROGRAMS\${PRETTY_NAME}"

    SetShellVarContext current
    Call CreateShortcuts

shortcuts_done:
    SetShellVarContext current
SectionEnd

;;; ---------------------------------------------------------------------------
;;; Shortcut helper (called for both all-users and current-user attempts)
;;; ---------------------------------------------------------------------------
Function CreateShortcuts
    CreateDirectory "$SMPROGRAMS\${PRETTY_NAME}"

    ;; Launch via Denemo.bat (sets env vars) with minimized console window
    CreateShortCut "$SMPROGRAMS\${PRETTY_NAME}\${PRETTY_NAME}.lnk" \
        "${BAT}" "" "$INSTDIR\share\icons\hicolor\denemo.ico" 0 SW_SHOWMINIMIZED

    WriteINIStr "$SMPROGRAMS\${PRETTY_NAME}\Denemo Website.url" \
        "InternetShortcut" "URL" "https://www.denemo.org/"

    CreateShortCut "$SMPROGRAMS\${PRETTY_NAME}\Uninstall ${PRETTY_NAME}.lnk" \
        "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0

    CreateShortCut "$DESKTOP\${PRETTY_NAME}.lnk" \
        "${BAT}" "" "$INSTDIR\share\icons\hicolor\denemo.ico" 0 SW_SHOWMINIMIZED
FunctionEnd

;;; ---------------------------------------------------------------------------
;;; Section descriptions (shown in components page tooltip)
;;; ---------------------------------------------------------------------------
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecMain}      \
        "The core Denemo application and all required libraries."
    !insertmacro MUI_DESCRIPTION_TEXT ${SecShortcuts} \
        "Add shortcuts to the Start Menu and Desktop."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

;;; ---------------------------------------------------------------------------
;;; LilyPond post-install: register .ly file association
;;; ---------------------------------------------------------------------------
Function postinstall_lilypond
    ; Register .ly file type so LilyPond files open with Denemo
    WriteRegStr HKCR ".ly"              "" "LilyPond"
    WriteRegStr HKCR "LilyPond"         "" "LilyPond File"
    WriteRegStr HKCR "LilyPond\shell"   "" "open"
    WriteRegExpandStr HKCR "LilyPond\shell\open\command" "" \
        '"$INSTDIR\bin\denemo.exe" "%1"'
FunctionEnd

;;; ---------------------------------------------------------------------------
;;; Uninstaller
;;; ---------------------------------------------------------------------------
Section "Uninstall"
    ;; Remove registry entries
    DeleteRegKey HKLM "${INSTALL_KEY}"
    DeleteRegKey HKLM "${UNINSTALL_KEY}"
    DeleteRegKey HKCR "LilyPond"
    DeleteRegKey HKCR ".ly"

    ;; Remove from PATH
    Call un.RemoveFromPath

    ;; Remove shortcuts (all-users and current-user)
    SetShellVarContext all
    Delete "$DESKTOP\${PRETTY_NAME}.lnk"
    Delete "$SMPROGRAMS\${PRETTY_NAME}\*.*"
    RMDir  "$SMPROGRAMS\${PRETTY_NAME}"

    SetShellVarContext current
    Delete "$DESKTOP\${PRETTY_NAME}.lnk"
    Delete "$SMPROGRAMS\${PRETTY_NAME}\*.*"
    RMDir  "$SMPROGRAMS\${PRETTY_NAME}"

    ;; *** ADD THIS — remove all installed content ***
    RMDir /r "$INSTDIR\bin"
    RMDir /r "$INSTDIR\etc"
    RMDir /r "$INSTDIR\lib"
    RMDir /r "$INSTDIR\share"
    RMDir /r "$INSTDIR\lilypond"
    RMDir /r "$INSTDIR\license"
    Delete    "$INSTDIR\Denemo.bat"
    Delete    "$INSTDIR\uninstall.exe"

    ;; Remove install dir if now empty
    RMDir "$INSTDIR"
SectionEnd

