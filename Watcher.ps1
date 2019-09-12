## Watcher seteup, checks if file is created and runs script
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "\\SYDMON2016P01\CreateUserAD"
$watcher.Filter = "*.*"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true 

## Runs powershell script as an Administrator
$action = 
{
    Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Unrestricted -File "C:\AutoCreateADUser\CreateADUser.ps1" -Verb RunAs'
}

## Defines what events are being watched
Register-ObjectEvent $watcher "Created" -Action $action

while ($true) {sleep 5}