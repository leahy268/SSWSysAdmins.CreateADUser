## Watcher seteup, checks if file is created and runs script
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "\\SYDMON2016P01\CreateUserAD"
$watcher.Filter = "*.*"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true 
$action = 
{

C:\AutoCreateADUser\CreateADUser.ps1

}
## Defines what events are being watched
Register-ObjectEvent $watcher "Created" -Action $action

while ($true) {sleep 5}