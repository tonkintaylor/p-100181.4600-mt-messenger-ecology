@ECHO OFF
WHERE pwsh > nul 2> nul && (pwsh -ExecutionPolicy Bypass -File "./tasks/shims/install.ps1" & EXIT /B)
WHERE powershell > nul 2> nul && (powershell -ExecutionPolicy Bypass -File "./tasks/shims/install.ps1" & EXIT /B)
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -File "./tasks/shims/install.ps1"
