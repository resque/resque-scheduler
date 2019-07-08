ECHO off

ECHO "exit" | bundle console > null

if %errorlevel% == 0 (
  ECHO "bundle console succeeded"
) ELSE (
  ECHO "bundle console failed"
  exit 1
)
