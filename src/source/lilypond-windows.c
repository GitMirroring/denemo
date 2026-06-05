#include <windows.h>
#include <stdio.h>
#include <string.h>

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow)
{
    STARTUPINFOA si;
    PROCESS_INFORMATION pi;
    char cmdline[4096];
    char exepath[MAX_PATH];
    DWORD exitcode;
    (void)hInstance;
    (void)hPrevInstance;
    (void)nCmdShow;
    GetModuleFileNameA(NULL, exepath, MAX_PATH);
    char *last = strrchr(exepath, '\\');
    if (last) last[1] = '\0';
    strncat(exepath, "lilypond.exe", MAX_PATH - strlen(exepath) - 1);
    if (lpCmdLine && lpCmdLine[0] != '\0')
        snprintf(cmdline, sizeof(cmdline), "\"%s\" %s", exepath, lpCmdLine);
    else
        snprintf(cmdline, sizeof(cmdline), "\"%s\"", exepath);
    memset(&si, 0, sizeof(si));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESTDHANDLES;
    si.hStdInput  = GetStdHandle(STD_INPUT_HANDLE);
    si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
    si.hStdError  = GetStdHandle(STD_ERROR_HANDLE);
    memset(&pi, 0, sizeof(pi));
    if (!CreateProcessA(NULL, cmdline, NULL, NULL, TRUE,
                        CREATE_NO_WINDOW, NULL, NULL, &si, &pi))
        return 1;
    WaitForSingleObject(pi.hProcess, INFINITE);
    GetExitCodeProcess(pi.hProcess, &exitcode);
    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);
    return (int)exitcode;
