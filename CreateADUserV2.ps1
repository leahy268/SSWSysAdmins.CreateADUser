## Consolidated and fixed errors in previous script

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
$SharePointUser = “sp_svc@ssw.com.au”
$SharePointPasswordContent = cat "C:\AutoCreateADUser\PasswordSharePoint.txt"
$SharePointPassword = ConvertTo-SecureString -String $SharePointPasswordContent -AsPlainText -Force
$SharePointCred = new-object -typename System.Management.Automation.PSCredential -argumentlist $SharePointUser, $SharePointPassword
$SharePointSiteUrl = "https://sswcom.sharepoint.com/sysadmin"
Connect-PnPOnline –Url $SharePointSiteUrl –Credentials $SharePointCred -NoTelemetry

## Define credentials for Exchange Remote Mailbox Enable, also partially used with creating skype user
$ExchangeServer = "SYDEXCH2016P01"
$SkypeExchUsername = “SRV_CreateADUser@ssw.com.au”
$SkypeExchPasswordContent = cat "C:\AutoCreateADUser\PasswordExchange.txt"
$SkypeExchPassword = ConvertTo-SecureString -String $SkypeExchPasswordContent -AsPlainText -Force
$SkypeExchCred = new-object -typename System.Management.Automation.PSCredential -argumentlist $SkypeExchUsername, $SkypeExchPassword
$ExchangeSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$ExchangeServer/PowerShell/" -Authentication Kerberos -Credential $Cred2

## Defines List in SharePoint Title is used for SysAdmin_User_UPN
$ListName = "New AD User"
$UserList = (Get-PnPListItem -List $ListName -Fields "Title","SysAdmin_User_Name", "SysAdmin_User_GivenName","SysAdmin_User_Surname","SysAdmin_User_DisplayName","SysAdmin_User_Office", 
"SysAdmin_User_Email","SysAdmin_User_Street","SysAdmin_User_City","SysAdmin_User_State", "SysAdmin_User_PostCode","SysAdmin_User_MobilePhone","SysAdmin_User_JobTitle","SysAdmin_User_Manager",
"SysAdmin_User_OU","SysAdmin_User_SAM","SysAdmin_User_Created","SysAdmin_User_Groups","SysAdmin_User_Country","SysAdmin_User_AltEmail")

## Define credentials for Skype User Creation
$SkypeServer = "SYDLYNC2013P01.sydney.ssw.com.au"
$SkypeSession = New-PSSession -ConnectionUri "https://$SkypeServer/ocsPowerShell/" -Credential $SkypeExchCred

## Create each user with a Created status of false
foreach($User in $UserList)
{  

    $User_SAM=$User["SysAdmin_User_SAM"]

    if ($User["SysAdmin_User_Created"] -eq $false)
    {

        LogWrite "Creating User in AD: " $User["SysAdmin_User_GivenName"] " " $User["SysAdmin_User_Surname"]""
        New-ADUser -Name $User["SysAdmin_User_Name"] -GivenName $User["SysAdmin_User_GivenName"] -Surname $User["SysAdmin_User_Surname"] -Description $User["SysAdmin_User_JobTitle"] -DisplayName $User["SysAdmin_User_DisplayName"] -Office $User["SysAdmin_User_Office"] -EmailAddress $User["SysAdmin_User_Email"] -StreetAddress $User["SysAdmin_User_Street"] -City $User["SysAdmin_User_City"] -State $User["SysAdmin_User_State"] -PostalCode $User["SysAdmin_User_PostCode"] -MobilePhone $User["SysAdmin_User_MobilePhone"] -Title $User["SysAdmin_User_JobTitle"] -Manager $User["SysAdmin_User_Manager"] -SamAccountName $User_SAM -Path $User["SysAdmin_User_OU"]  -UserPrincipalName $User["Title"] -Company "SSW" -Country $User["SysAdmin_User_Country"]
        ## Had to initiate this after creating user, otherwise I was recieving errors
        Set-ADAccountPassword -Identity $User_SAM -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "This!c03f0l9" -Force)
        Set-AdUser -Identity $User_SAM -Enabled:$True -PasswordNeverExpires:$True -ChangePasswordAtLogon:$False
        ## Seperated the below two as I am unsure if we are using the "extensionAttribute1"
        Set-ADUser -Identity $User_SAM -Add @{Proxyaddresses="SMTP:"+$User_SAM+'@sswcom.onmicrosoft.com';c=$User["SysAdmin_User_Country"]}
        Set-ADUser -Identity $User_SAM -Add @{extensionAttribute1=$User["SysAdmin_User_AltEmail"]}
        ## Assign Group Membership, seperated as I need to remove the ', ' before applying
        $GroupString = ($User["SysAdmin_User_Groups"] -split ', ')
        Add-ADPrincipalGroupMembership $User_SAM -MemberOf $GroupString  
        LogWrite "Finished creating AD user: " $User["SysAdmin_User_GivenName"] " " $User["SysAdmin_User_Surname"]""
        
        ## Sync to O365 through AAD Connect
        LogWrite "Syncing new users to O365 using AAD Connect"
        Enable-PSRemoting -Force
        Invoke-Command -ComputerName SYDADFSP01 -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Delta }
        LogWrite "Syncing complete"

        ## Wait for user to be provisioned in O365 this generally takes around 60 seconds
        ## TO DO add a While command so that I can determine with true value if the user is provisioned before moving one, instead of based on time, need to add O365 commands here, user cannot be MFA enabled
        Start-Sleep -Seconds 90
        
        ## Provison remote mailbox on eonpremises Exchange server, if this is not needed comment out section
        LogWrite "Enabling Remote Mailbox: " $User["SysAdmin_User_GivenName"] " " $User["SysAdmin_User_Surname"]""
        Import-PSSession $Session
        Enable-RemoteMailbox -Identity $User_SAM+'@ssw.com.au' -RemoteRoutingAddress $User_SAM'@sswcom.onmicrosoft.com'
        Update-OfflineAddressBook -Identity "Default Offline Address Book"
        Update-GlobalAddressList -Identity "Default Global Address List"
        Remove-PSSession $Session
        LogWrite "Completed enabling remote mailbox"

        ## Provision Skype User, this just provisions pc-to-pc comms, no site or # is added
        LogWrite "Creating Skype Profile for: " $User["SysAdmin_User_GivenName"] " " $User["SysAdmin_User_Surname"]""
        Import-PSSession $Session
        Enable-CsUser -Identity $User_SAM -RegistrarPool "SydLync2013P01.sydney.ssw.com.au" -SipAddressType SamAccountName -SipDomain ssw.com.au
        Remove-PSSession $Session
        LogWrite "Completed creating skype profile"
        
    }
}  

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