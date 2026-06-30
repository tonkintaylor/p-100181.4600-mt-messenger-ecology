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

; Shortcuts launch the GUI stub exe (no console window; carries the app icon).
[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\MtMessengerPipeline.exe"; \
  WorkingDir: "{app}"; IconFilename: "{app}\app.ico"
Name: "{userdesktop}\{#AppName}"; Filename: "{app}\MtMessengerPipeline.exe"; \
  WorkingDir: "{app}"; IconFilename: "{app}\app.ico"

[Run]
Filename: "{app}\MtMessengerPipeline.exe"; WorkingDir: "{app}"; \
  Description: "Launch now"; Flags: postinstall nowait skipifsilent
