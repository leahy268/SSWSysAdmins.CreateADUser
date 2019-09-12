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

$Logfile = "C:\AutoCreateADUser\Log.txt"
LogWrite "Auto Create User Log Started"

## Define credentials and login to SharePoint with PnPOnline
$Username = “sp_svc@ssw.com.au”
$PasswordContent = cat "C:\AutoCreateADUser\PasswordSharePoint.txt"
$Password = ConvertTo-SecureString -String $PasswordContent -AsPlainText -Force
$Cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $Username, $Password
$SiteUrl = "https://sswcom.sharepoint.com/sysadmin"
Connect-PnPOnline –Url $SiteUrl –Credentials $Cred -NoTelemetry

## Defines List in SharePoint Title is used for SysAdmin_User_UPN
$ListName = "New AD User"
$UserList = (Get-PnPListItem -List $ListName -Fields "Title","SysAdmin_User_Name", "SysAdmin_User_GivenName","SysAdmin_User_Surname","SysAdmin_User_DisplayName","SysAdmin_User_Office", 
"SysAdmin_User_Email","SysAdmin_User_Street","SysAdmin_User_City","SysAdmin_User_State", "SysAdmin_User_PostCode","SysAdmin_User_MobilePhone","SysAdmin_User_JobTitle","SysAdmin_User_Manager",
"SysAdmin_User_OU","SysAdmin_User_SAM","SysAdmin_User_Created","SysAdmin_User_Groups","SysAdmin_User_Country","SysAdmin_User_AltEmail")

## Create each user with a Created status of false
foreach($User in $UserList)
{  
    if ($User["SysAdmin_User_Created"] -eq $false)
    {
        LogWrite "Creating User in AD: " $User["SysAdmin_User_GivenName"] " " $User["SysAdmin_User_Surname"]""
        New-ADUser -Name $User["SysAdmin_User_Name"] -GivenName $User["SysAdmin_User_GivenName"] -Surname $User["SysAdmin_User_Surname"] -Description $User["SysAdmin_User_JobTitle"] -DisplayName $User["SysAdmin_User_DisplayName"] -Office $User["SysAdmin_User_Office"] -EmailAddress $User["SysAdmin_User_Email"] -StreetAddress $User["SysAdmin_User_Street"] -City $User["SysAdmin_User_City"] -State $User["SysAdmin_User_State"] -PostalCode $User["SysAdmin_User_PostCode"] -MobilePhone $User["SysAdmin_User_MobilePhone"] -Title $User["SysAdmin_User_JobTitle"] -Manager $User["SysAdmin_User_Manager"] -SamAccountName $User["SysAdmin_User_SAM"] -Path $User["SysAdmin_User_OU"]  -UserPrincipalName $User["Title"] -Company "SSW" -Country $User["SysAdmin_User_Country"]
        Set-ADAccountPassword -Identity $User["SysAdmin_User_SAM"] -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "This!c03f0l9" -Force)
        Set-AdUser -Identity $User["SysAdmin_User_SAM"] -Enabled:$True -PasswordNeverExpires:$True -ChangePasswordAtLogon:$False
        Set-ADUser -Identity $User["SysAdmin_User_SAM"] -Add @{Proxyaddresses="SMTP:"+$User["SysAdmin_User_SAM"]+'@sswcom.onmicrosoft.com';c=$User["SysAdmin_User_Country"]}
        Set-ADUser -Identity $User["SysAdmin_User_SAM"] -Add @{extensionAttribute1=$User["SysAdmin_User_AltEmail"]}
        $GroupString = ($User["SysAdmin_User_Groups"] -split ', ')
        Add-ADPrincipalGroupMembership $User["SysAdmin_User_SAM"] -MemberOf $GroupString  
        LogWrite "Finished creating AD user: " $User["SysAdmin_User_GivenName"] " " $User["SysAdmin_User_Surname"]""
        #TODO: SEND EMAIL Success or Fail could use TRY commads
    }
}  

## Sync to O365
LogWrite "Syncing new users to O365 using AAD Connect"
Enable-PSRemoting -Force
Invoke-Command -ComputerName SYDADFSP01 -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Delta }
LogWrite "Syncing complete"

## Wait for user to be provisioned in O365 this generally takes around 60 seconds
Start-Sleep -Seconds 90

## Define credentials for Exchange Remote Mailbox Enable, also partially used with creating skype user
$Exchange = "SYDEXCH2016P01"
$Username2 = “SRV_CreateADUser@ssw.com.au”
$PasswordContent2 = cat "C:\AutoCreateADUser\PasswordExchange.txt"
$Password2 = ConvertTo-SecureString -String $PasswordContent2 -AsPlainText -Force
$Cred2 = new-object -typename System.Management.Automation.PSCredential -argumentlist $Username2, $Password2
$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$Exchange/PowerShell/" -Authentication Kerberos -Credential $Cred2

## Enable remote mailbox and sync GAL and OAB
foreach($User in $UserList)
{  
    
    if ($User["SysAdmin_User_Created"] -eq $false)
    {

            LogWrite "Enabling Remote Mailbox: " $User["SysAdmin_User_GivenName"] " " $User["SysAdmin_User_Surname"]""
            Import-PSSession $Session
            $User=$User["SysAdmin_User_SAM"]
            Enable-RemoteMailbox -Identity $User@ssw.com.au -RemoteRoutingAddress $User@sswcom.onmicrosoft.com
            Update-OfflineAddressBook -Identity "Default Offline Address Book"
            Update-GlobalAddressList -Identity "Default Global Address List"
            LogWrite "Completed enabling remote mailbox"

    }   

}

Remove-PSSession $Session

## Define credentials for Skype User Creation
$Skype = "SYDLYNC2013P01.sydney.ssw.com.au"
$Session = New-PSSession -ConnectionUri "https://SYDLYNC2013P01.sydney.ssw.com.au/ocsPowerShell/" -Credential $Cred2 

## Create Skype User
foreach($User in $UserList)
{  
    
    if ($User["SysAdmin_User_Created"] -eq $false)
    {

            LogWrite "Creating Skype Profile for: " $User["SysAdmin_User_GivenName"] " " $User["SysAdmin_User_Surname"]""
            Import-PSSession $Session
            Enable-CsUser -Identity $User["SysAdmin_User_SAM"] -RegistrarPool "SydLync2013P01.sydney.ssw.com.au" -SipAddressType SamAccountName -SipDomain ssw.com.au
            LogWrite "Completed creating skype profile"

    }   

}

Remove-PSSession $Session

############################ TO DO ############################

#1. Provision Skype User. 
    # DONE
#2. Randomly generate password. (10min characters, not contain user account name or parts of user's full name that exceed two characters, Containt three of: A-Z, a-z, 0-9, !$#%)
#3. Add line to add personal email, flow and script.
    # DONE
#4. Add a nill access user, just has O365 applied
    # DONE
#5. Get watcher script to run CreateADUser.ps1 properly. At the moment it gets stuck at Sycning AAD Connect. 
    # DONE
#6. Update documentation
#7. Update SharePoint username to SP_SVC
    # DONE
#8. Log file to capture all output
#9. Send Email

############################ TO DO ############################