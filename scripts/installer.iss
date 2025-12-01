; SmartGridSlicer - Inno Setup 安装脚本
; 用于生成 Windows 安装程序

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

#ifndef BuildPath
  #define BuildPath "..\build\windows\x64\runner\Release"
#endif

#ifndef OutputPath
  #define OutputPath ".."
#endif

#define AppName "SmartGridSlicer"
#define AppPublisher "silevilence"
#define AppURL "https://github.com/silevilence/split_image_app"
#define AppExeName "split_image_app.exe"
#define AppDescription "贴纸图集切割工具 - 将贴纸图集按网格切割成独立图片"

[Setup]
; 应用程序信息
AppId={{8A9F5E2D-7C3B-4A1E-9D6F-2B8E4C5A7D3F}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}/releases

; 安装目录
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes

; 输出设置
OutputDir={#OutputPath}
OutputBaseFilename={#AppName}-{#AppVersion}-setup
Compression=lzma2/ultra64
SolidCompression=yes
LZMANumBlockThreads=4

; 安装程序外观
WizardStyle=modern

; 权限设置
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; 其他设置
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}

; 版本信息
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#AppPublisher}
VersionInfoDescription={#AppDescription}
VersionInfoCopyright=Copyright (C) 2025 {#AppPublisher}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
; 简体中文语言包需要额外安装，如果存在则取消下面的注释
; Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; 主程序及所有依赖
Source: "{#BuildPath}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; 注意: 不要在任何共享系统文件上使用 "Flags: ignoreversion"

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Comment: "{#AppDescription}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon; Comment: "{#AppDescription}"

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(AppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Registry]
; 文件关联 (可选 - 暂时注释)
; Root: HKCU; Subkey: "Software\Classes\.png\OpenWithList\{#AppExeName}"; Flags: uninsdeletekey
; Root: HKCU; Subkey: "Software\Classes\.jpg\OpenWithList\{#AppExeName}"; Flags: uninsdeletekey

[Code]
// 检查是否已安装旧版本
function InitializeSetup: Boolean;
var
  UninstallKey: String;
  InstalledVersion: String;
begin
  Result := True;
  
  // 检查注册表中的已安装版本
  UninstallKey := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{8A9F5E2D-7C3B-4A1E-9D6F-2B8E4C5A7D3F}_is1';
  
  if RegQueryStringValue(HKCU, UninstallKey, 'DisplayVersion', InstalledVersion) or
     RegQueryStringValue(HKLM, UninstallKey, 'DisplayVersion', InstalledVersion) then
  begin
    if CompareStr(InstalledVersion, '{#AppVersion}') >= 0 then
    begin
      if MsgBox('检测到已安装 ' + InstalledVersion + ' 版本。' + #13#10 +
                '当前版本为 {#AppVersion}。' + #13#10#13#10 +
                '是否继续安装？', mbConfirmation, MB_YESNO) = IDNO then
      begin
        Result := False;
      end;
    end;
  end;
end;

// 安装前清理旧文件 (可选)
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssInstall then
  begin
    // 可以在这里添加清理逻辑
  end;
end;
