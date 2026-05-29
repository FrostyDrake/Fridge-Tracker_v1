$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'flutter-env.ps1')

flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 --no-pub
