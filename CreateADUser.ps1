## Install PnPOline on user that will be running server: https://github.com/SharePoint/pnp-powershell/releases

## Let's create a log so we can see what is happening
Function LogWrite
{
   $Systemusername = $env:USERNAME
   $PcName = $env:computername
   $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
   $Line = "$Stamp $PcName $Systemusername $args"
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
    $User_SAM = $User["SysAdmin_User_SAM"]
    $Firstname = $User["SysAdmin_User_GivenName"]
    $Surname = $User["SysAdmin_User_Surname"]
    $Pre2000 = $User["SysAdmin_User_GivenName"]+$User["SysAdmin_User_Surname"] -replace '[^a-zA-Z0-9]', ''
    $Username = $Pre2000.substring(0, [System.Math]::Min(20, $Pre2000.Length))
    $Email = $User["Title"]
    $Mobile = $User["SysAdmin_User_MobilePhone"]
    
        try{
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
        }
        catch{
        $UserCreation = "User Creation has failed, please check all inputs are correct."
        LogWrite "User Creation has failed, please check all inputs are correct."
         
        $bodyhtml =  "<div style='font-family:Calibri;'>"
        $bodyhtml += "</H3>"
        $bodyhtml += "<p>There was an issue creating a new user, at the AD User Creation phase.</p>"
        
        $bodyhtml += "<b>Firstname:</b> $Firstname<br>"
        $bodyhtml += "<b>Surname:</b> $Surname<br>"

        $bodyhtml += "<p>Tip: You can find a log file with more information at <a href=$LogFile> $LogFile </a></p>"
        $bodyhtml += "<p>Documentation for the SSW Blacklist Checker: <br>"
        $bodyhtml += "Public - <a href=https://github.com/SSWConsulting/SSWCreateADUser> SSWCreateADUser Github </a><br>"
        $bodyhtml += "Internal - <a href=https://sswcom.sharepoint.com/:w:/g/SysAdmin/EXvH_G59-QNAgusHshEhQtEB8egZa_pXAdAZb8SlCx20Pw?e=bfFt93> SSWCreateADUser SharePoint </a></p>"
        $bodyhtml += "<p></p>"
        $bodyhtml += "<p>-- Powered by SSW.CreateADUser<br /> Server: $env:computername </p>"
        
        Send-MailMessage -from "sswserverevents@ssw.com.au" -to "SSWSysAdmins@ssw.com.au" -Subject "New AD User Created for - $Firstname $Surname has failed" -Body $bodyhtml -SmtpServer "ssw-com-au.mail.protection.outlook.com" -bodyashtml

        break
        }

        try{
        ## Sync to O365 through AAD Connect
        LogWrite "Syncing new users to O365 using AAD Connect"
        Enable-PSRemoting -Force
        Invoke-Command -ComputerName SYDADFSP01 -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Delta }

        ## Wait for user to be provisioned in O365 this generally takes around 60 seconds
        ## TO DO add a While command so that I can determine with true value if the user is provisioned before moving one, instead of based on time, need to add O365 commands here, user cannot be MFA enabled
        Start-Sleep -Seconds 90
        LogWrite "Syncing complete"
        #Remove-PSSession
        }
        catch{
        $UserSync = "User sync has failed."
        LogWrite "User sync has failed."
       
        $bodyhtml =  "<div style='font-family:Calibri;'>"
        $bodyhtml += "</H3>"
        $bodyhtml += "<p>There was an issue creating a new user, at the O365 sync stage.</p>"
        
        $bodyhtml += "<b>Firstname:</b> $Firstname<br>"
        $bodyhtml += "<b>Surname:</b> $Surname<br>"

        $bodyhtml += "<p>Tip: You can find a log file with more information at <a href=$LogFile> $LogFile </a></p>"
        $bodyhtml += "<p>Documentation for the SSW Blacklist Checker: <br>"
        $bodyhtml += "Public - <a href=https://github.com/SSWConsulting/SSWCreateADUser> SSWCreateADUser Github </a><br>"
        $bodyhtml += "Internal - <a href=https://sswcom.sharepoint.com/:w:/g/SysAdmin/EXvH_G59-QNAgusHshEhQtEB8egZa_pXAdAZb8SlCx20Pw?e=bfFt93> SSWCreateADUser SharePoint </a></p>"
        $bodyhtml += "<p></p>"
        $bodyhtml += "<p>-- Powered by SSW.CreateADUser<br /> Server: $env:computername </p>"
        
        Send-MailMessage -from "sswserverevents@ssw.com.au" -to "SSWSysAdmins@ssw.com.au" -Subject "New AD User Created for - $Firstname $Surname has failed" -Body $bodyhtml -SmtpServer "ssw-com-au.mail.protection.outlook.com" -bodyashtml

        break
        }

        ## Define credentials for Exchange Remote Mailbox Enable, also partially used with creating skype user
        $ExchangeServer = "SYDEXCH2016P01"
        $SkypeExchUsername = “SRV_CreateADUser@ssw.com.au”
        $SkypeExchPasswordContent = cat "C:\AutoCreateADUser\PasswordExchange.txt"
        $SkypeExchPassword = ConvertTo-SecureString -String $SkypeExchPasswordContent -AsPlainText -Force
        $SkypeExchCred = new-object -typename System.Management.Automation.PSCredential -argumentlist $SkypeExchUsername, $SkypeExchPassword
        $ExchangeSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri "http://$ExchangeServer/PowerShell/" -Authentication Kerberos -Credential $SkypeExchCred

        try{
        ## Provison remote mailbox on eonpremises Exchange server, if this is not needed comment out section
        LogWrite "Enabling Remote Mailbox: " $User["SysAdmin_User_GivenName"] " " $User["SysAdmin_User_Surname"]""
        Import-PSSession $ExchangeSession
        Enable-RemoteMailbox -Identity $User_SAM'@ssw.com.au' -RemoteRoutingAddress $User_SAM'@sswcom.onmicrosoft.com'
        Update-OfflineAddressBook -Identity "Default Offline Address Book"
        Update-GlobalAddressList -Identity "Default Global Address List"
        Remove-PSSession $ExchangeSession
        LogWrite "Completed enabling remote mailbox"
        }
        catch{
        $UserRemoteMail = "User enable remote mailbox has failed, please check user has synced to O365."
        LogWrite "User enable remote mailbox has failed, please check user has synced to O365."
               
        $bodyhtml =  "<div style='font-family:Calibri;'>"
        $bodyhtml += "</H3>"
        $bodyhtml += "<p>There was an issue creating a new user, at the enable remote mailbox phase.</p>"
        
        $bodyhtml += "<b>Firstname:</b> $Firstname<br>"
        $bodyhtml += "<b>Surname:</b> $Surname<br>"

        $bodyhtml += "<p>Tip: You can find a log file with more information at <a href=$LogFile> $LogFile </a></p>"
        $bodyhtml += "<p>Documentation for the SSW Blacklist Checker: <br>"
        $bodyhtml += "Public - <a href=https://github.com/SSWConsulting/SSWCreateADUser> SSWCreateADUser Github </a><br>"
        $bodyhtml += "Internal - <a href=https://sswcom.sharepoint.com/:w:/g/SysAdmin/EXvH_G59-QNAgusHshEhQtEB8egZa_pXAdAZb8SlCx20Pw?e=bfFt93> SSWCreateADUser SharePoint </a></p>"
        $bodyhtml += "<p></p>"
        $bodyhtml += "<p>-- Powered by SSW.CreateADUser<br /> Server: $env:computername </p>"
        
        Send-MailMessage -from "sswserverevents@ssw.com.au" -to "SSWSysAdmins@ssw.com.au" -Subject "New AD User Created for - $Firstname $Surname has failed" -Body $bodyhtml -SmtpServer "ssw-com-au.mail.protection.outlook.com" -bodyashtml

        break
        }

        ## Define credentials for Skype User Creation
        $SkypeServer = "SYDLYNC2013P01.sydney.ssw.com.au"
        $SkypeSession = New-PSSession -ConnectionUri "https://$SkypeServer/ocsPowerShell/" -Credential $SkypeExchCred

        try{
        ## Provision Skype User, this just provisions pc-to-pc comms, no site or # is added
        LogWrite "Creating Skype Profile for: " $User["SysAdmin_User_GivenName"] " " $User["SysAdmin_User_Surname"]""
        Import-PSSession $SkypeSession
        Enable-CsUser -Identity $User_SAM -RegistrarPool "SydLync2013P01.sydney.ssw.com.au" -SipAddressType SamAccountName -SipDomain ssw.com.au
        Remove-PSSession $SkypeSession
        LogWrite "Completed creating skype profile"
        }
        catch{
        $UserRemoteMail = "Enabling user for Skype has failed."
        LogWrite "Enabling user for Skype has failed."
               
        $bodyhtml =  "<div style='font-family:Calibri;'>"
        $bodyhtml += "</H3>"
        $bodyhtml += "<p>There was an issue creating a new user, at the enable skype user phase.</p>"
        
        $bodyhtml += "<b>Firstname:</b> $Firstname<br>"
        $bodyhtml += "<b>Surname:</b> $Surname<br>"

        $bodyhtml += "<p>Tip: You can find a log file with more information at <a href=$LogFile> $LogFile </a></p>"
        $bodyhtml += "<p>Documentation for the SSW Blacklist Checker: <br>"
        $bodyhtml += "Public - <a href=https://github.com/SSWConsulting/SSWCreateADUser> SSWCreateADUser Github </a><br>"
        $bodyhtml += "Internal - <a href=https://sswcom.sharepoint.com/:w:/g/SysAdmin/EXvH_G59-QNAgusHshEhQtEB8egZa_pXAdAZb8SlCx20Pw?e=bfFt93> SSWCreateADUser SharePoint </a></p>"
        $bodyhtml += "<p></p>"
        $bodyhtml += "<p>-- Powered by SSW.CreateADUser<br /> Server: $env:computername </p>"
        
        Send-MailMessage -from "sswserverevents@ssw.com.au" -to "SSWSysAdmins@ssw.com.au" -Subject "New AD User Created for - $Firstname $Surname has failed" -Body $bodyhtml -SmtpServer "ssw-com-au.mail.protection.outlook.com" -bodyashtml
        
        break
        }

        try{
        ## Change SysAdmin_User_Created Boolean to $true
		Set-PnPListItem -List "New AD User" -Identity $User["ID"] -Values @{"SysAdmin_User_Created" = $true}
        }
        catch{
        $UserRemoteMail = "Changing SysAdmin_User_Created Boolean to true has failed."
        LogWrite "Changing SysAdmin_User_Created Boolean to true has failed."
               
        $bodyhtml =  "<div style='font-family:Calibri;'>"
        $bodyhtml += "</H3>"
        $bodyhtml += "<p>There was an issue creating a new user, Changing SysAdmin_User_Created Boolean to true has failed phase.</p>"
        
        $bodyhtml += "<b>Firstname:</b> $Firstname<br>"
        $bodyhtml += "<b>Surname:</b> $Surname<br>"

        $bodyhtml += "<p>Tip: You can find a log file with more information at <a href=$LogFile> $LogFile </a></p>"
        $bodyhtml += "<p>Documentation for the SSW Blacklist Checker: <br>"
        $bodyhtml += "Public - <a href=https://github.com/SSWConsulting/SSWCreateADUser> SSWCreateADUser Github </a><br>"
        $bodyhtml += "Internal - <a href=https://sswcom.sharepoint.com/:w:/g/SysAdmin/EXvH_G59-QNAgusHshEhQtEB8egZa_pXAdAZb8SlCx20Pw?e=bfFt93> SSWCreateADUser SharePoint </a></p>"
        $bodyhtml += "<p></p>"
        $bodyhtml += "<p>-- Powered by SSW.CreateADUser<br /> Server: $env:computername </p>"
        
        Send-MailMessage -from "sswserverevents@ssw.com.au" -to "SSWSysAdmins@ssw.com.au" -Subject "New AD User Created for - $Firstname $Surname has failed" -Body $bodyhtml -SmtpServer "ssw-com-au.mail.protection.outlook.com" -bodyashtml
        
        break
        }

        ## Send Email
        $bodyhtml =  "<div style='font-family:Calibri;'>"
        $bodyhtml += "</H3>"
        $bodyhtml += "<p>We just created a new AD user.</p>"
        
        $bodyhtml += "<b>Firstname:</b> $Firstname<br>"
        $bodyhtml += "<b>Surname:</b> $Surname<br>"
        $bodyhtml += "<b>Username:</b> SSW2000\$Username<br>"
        $bodyhtml += "<b>Email:</b> $Email<br>"
        $bodyhtml += "<b>Mobile:</b> $Mobile<br>"

        $bodyhtml += "<p>Tip: You can find a log file with more information at <a href=$LogFile> $LogFile </a></p>"
        $bodyhtml += "<p>Documentation for the SSW Blacklist Checker: <br>"
        $bodyhtml += "Public - <a href=https://github.com/SSWConsulting/SSWCreateADUser> SSWCreateADUser Github </a><br>"
        $bodyhtml += "Internal - <a href=https://sswcom.sharepoint.com/:w:/g/SysAdmin/EXvH_G59-QNAgusHshEhQtEB8egZa_pXAdAZb8SlCx20Pw?e=bfFt93> SSWCreateADUser SharePoint </a></p>"
        $bodyhtml += "<p></p>"
        $bodyhtml += "<p>-- Powered by SSW.CreateADUser<br /> Server: $env:computername </p>"

        Send-MailMessage -from "sswserverevents@ssw.com.au" -to "SSWSysAdmins@ssw.com.au" -Subject "New AD User Created for - $Firstname $Surname" -Body $bodyhtml -SmtpServer "ssw-com-au.mail.protection.outlook.com" -bodyashtml


    }
}  