$ProjectRoot = Split-Path -Parent $PSScriptRoot
$FlutterRoot = Join-Path $ProjectRoot '.tools\flutter-sdk\flutter'

$env:Path = "C:\Program Files\Git\cmd;$($FlutterRoot)\bin;$env:Path"
$env:APPDATA = Join-Path $ProjectRoot '.tools\appdata\roaming'
$env:LOCALAPPDATA = Join-Path $ProjectRoot '.tools\appdata\local'
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:DART_SUPPRESS_ANALYTICS = 'true'
$env:CHROME_EXECUTABLE = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'

New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null
