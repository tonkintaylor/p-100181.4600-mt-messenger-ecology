; Per-user installer for the Mt Messenger pipeline launcher (no admin required).
; Build: ISCC.exe installer\MtMessengerPipeline.iss  (after tasks\build_launcher.ps1)
#define AppName "Mt Messenger Ecology Pipeline"
#define AppVer  "1.0.0"

[Setup]
AppName={#AppName}
AppVersion={#AppVer}
DefaultDirName={localappdata}\MtMessengerPipeline
DefaultGroupName={#AppName}
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
OutputBaseFilename=MtMessengerPipeline-Setup
OutputDir=..\build
UninstallDisplayIcon={app}\app.ico
SetupIconFile=..\launcher\app.ico

[Files]
Source: "..\build\launcher-app\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\launcher.ps1"""; \
  IconFilename: "{app}\app.ico"
Name: "{userdesktop}\{#AppName}"; Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\launcher.ps1"""; \
  IconFilename: "{app}\app.ico"

[Run]
Filename: "powershell.exe"; \
  Parameters: "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""{app}\launcher.ps1"""; \
  Description: "Launch now"; Flags: postinstall nowait skipifsilent
