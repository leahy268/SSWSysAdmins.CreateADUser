## Watcher seteup, checks if file is created and runs script
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = "\\SYDMON2016P01\CreateUserAD"
$watcher.Filter = "*.*"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true 
$action = 
{

####################################################################################TO DO PERMISSIONS
## Let's create a log so we can see what is happening
Function LogWrite
{
   $username = $env:USERNAME
   
   $PcName = $env:computername


   $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
   $Line = "$Stamp $PcName $Username $args"


   Add-content $Logfile -value $Line
   Write-Host $Line
}

$Logfile = "C:\AutoCreateADUser"
LogWrite "Succesfully imported current block list..."
####################################################################################TO DO PERMISSIONS

## Define credentials and login to SharePoint
$Username = “windowsservice@ssw.com.au”
$PasswordContent = cat "C:\AutoCreateADUser\PasswordSharePoint.txt"
$Password = ConvertTo-SecureString -String $PasswordContent -AsPlainText -Force
$Cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $Username, $Password
$SiteUrl = "https://sswcom.sharepoint.com/sysadmin"
Connect-PnPOnline –Url $SiteUrl –Credentials $Cred -NoTelemetry

## Define credentials for Exchange Remote Mailbox Enable
$Exchange = "SYDEXCH2016P01"
$Username2 = “SRV_CreateADUser@ssw.com.au”
$PasswordContent2 = cat "C:\AutoCreateADUser\PasswordExchange.txt"
$Password2 = ConvertTo-SecureString -String $PasswordContent2 -AsPlainText -Force
$Cred2 = new-object -typename System.Management.Automation.PSCredential -argumentlist $Username2, $Password2
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$Exchange/PowerShell/" -Authentication Kerberos -Credential $UserCredential

## Defines List name in SharePoint
$ListName = "New AD User"

$UserList = (Get-PnPListItem -List $ListName -Fields "Title","SysAdmin_User_Name", "SysAdmin_User_GivenName","SysAdmin_User_Surname","SysAdmin_User_DisplayName","SysAdmin_User_Office", "SysAdmin_User_Email","SysAdmin_User_Street","SysAdmin_User_City","SysAdmin_User_State", "SysAdmin_User_PostCode","SysAdmin_User_MobilePhone","SysAdmin_User_JobTitle","SysAdmin_User_Manager","SysAdmin_User_OU","SysAdmin_User_SAM","SysAdmin_User_Created","SysAdmin_User_Groups","SysAdmin_User_Country")

## Item steps through each item in the array Items
foreach($User in $UserList)
{  
    if ($User["SysAdmin_User_Created"] -eq $false)
    {
        Write-Host "Creating User in AD " $User["SysAdmin_User_GivenName"] " " $User["SysAdmin_User_Surname"]")"
        
        New-ADUser -Name $User["SysAdmin_User_Name"] -GivenName $User["SysAdmin_User_GivenName"] -Surname $User["SysAdmin_User_Surname"] -Description $User["SysAdmin_User_JobTitle"] -DisplayName $User["SysAdmin_User_DisplayName"] -Office $User["SysAdmin_User_Office"] -EmailAddress $User["SysAdmin_User_Email"] -StreetAddress $User["SysAdmin_User_Street"] -City $User["SysAdmin_User_City"] -State $User["SysAdmin_User_State"] -PostalCode $User["SysAdmin_User_PostCode"] -MobilePhone $User["SysAdmin_User_MobilePhone"] -Title $User["SysAdmin_User_JobTitle"] -Manager $User["SysAdmin_User_Manager"] -SamAccountName $User["SysAdmin_User_SAM"] -Path $User["SysAdmin_User_OU"]  -UserPrincipalName $User["Title"] -Company "SSW" -Country $User["SysAdmin_User_Country"]

        Set-ADAccountPassword -Identity $User["SysAdmin_User_SAM"] -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "This!c03f0l9" -Force)

        Set-AdUser -Identity $User["SysAdmin_User_SAM"] -Enabled:$True -PasswordNeverExpires:$True -ChangePasswordAtLogon:$False

        Set-ADUser -Identity $User["SysAdmin_User_SAM"] -Add @{Proxyaddresses="SMTP:"+$User["SysAdmin_User_SAM"]+'@sswcom.onmicrosoft.com';c=$User["SysAdmin_User_Country"]}

        $GroupArray = ($User["SysAdmin_User_Groups"] -split ', ')

        foreach($Group in $GroupArray)
        {  
            $GroupString = $Group.Replace('"', '') ## Getting rid of quotes around

            Add-ADPrincipalGroupMembership $User["SysAdmin_User_SAM"] -MemberOf $GroupString  
        } 

        ## Hey Send Email !
        #TODO: SEND EMAIL Success or Fail could use TRY commads
    }
}  

## Porvision Skype Account
Enable-PSRemoting -Force
Invoke-Command -ComputerName SYDADFSP01 -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Delta }
 Write-Host "Syncing new users to O365 using AAD Connect."

## Wait for user to be provisioned in O365
Start-Sleep -Seconds 60

foreach($User in $UserList)
{  

    Write-Host "Enabling Remote Mailbox for " $User["SysAdmin_User_GivenName"] " " $User["SysAdmin_User_Surname"]")"
    Import-PSSession $Session
    Enable-RemoteMailbox -Identity $User["SysAdmin_User_SAM"]+@ssw.com.au

}   

## Defines what events are being watched
Register-ObjectEvent $watcher "Created" -Action $action

while ($true) {sleep 5}