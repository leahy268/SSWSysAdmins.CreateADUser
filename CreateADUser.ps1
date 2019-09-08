## Installs PnP
Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/sharepoint/PnP-PowerShell/master/Samples/Modules.Install/Install-SharePointPnPPowerShell.ps1')

## Connects to SharePoint Online
Connect-PnPOnline -Url https://sswcom.sharepoint.com/sysadmin

#Defines List name in SharePoint
$ListName = "New AD User"

$UserList = (Get-PnPListItem -List $ListName -Fields "Title","SysAdmin_User_Name", "SysAdmin_User_GivenName","SysAdmin_User_Surname","SysAdmin_User_DisplayName","SysAdmin_User_Office", "SysAdmin_User_Email","SysAdmin_User_Street","SysAdmin_User_City","SysAdmin_User_State", "SysAdmin_User_PostCode","SysAdmin_User_MobilePhone","SysAdmin_User_JobTitle","SysAdmin_User_Manager","SysAdmin_User_OU","SysAdmin_User_SAM","SysAdmin_User_Created","SysAdmin_User_Groups","SysAdmin_User_Country")


## Item steps through each item in the array Items
## TODO: Use a Switch statement to decide group membership ot create some logic with flows
#TODO: SEND EMAIL Success or Fail could use TRY commads

foreach($User in $UserList)
{  
    if ($User["SysAdmin_User_Created"] -eq $false)
    {
        Write-Host "Processing list item " $User["SysAdmin_User_GivenName"] " " $User["SysAdmin_User_Surname"]")"
        
        New-ADUser -Name $User["SysAdmin_User_Name"] -GivenName $User["SysAdmin_User_GivenName"] -Surname $User["SysAdmin_User_Surname"] -Description $User["SysAdmin_User_JobTitle"] -DisplayName $User["SysAdmin_User_DisplayName"] -Office $User["SysAdmin_User_Office"] -EmailAddress $User["SysAdmin_User_Email"] -StreetAddress $User["SysAdmin_User_Street"] -City $User["SysAdmin_User_City"] -State $User["SysAdmin_User_State"] -PostalCode $User["SysAdmin_User_PostCode"] -MobilePhone $User["SysAdmin_User_MobilePhone"] -Title $User["SysAdmin_User_JobTitle"] -Manager $User["SysAdmin_User_Manager"] -SamAccountName $User["SysAdmin_User_SAM"] -Path $User["SysAdmin_User_OU"]  -UserPrincipalName $User["Title"] -Company "SSW" -Country $User["SysAdmin_User_Country"]

        Set-ADAccountPassword -Identity $User["SysAdmin_User_SAM"] -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "This!c03f0l9" -Force)

        Set-AdUser -Identity $User["SysAdmin_User_SAM"] -Enabled:$True -PasswordNeverExpires:$True -ChangePasswordAtLogon:$False

        Set-ADUser -Identity $User["SysAdmin_User_SAM"] -Add @{Proxyaddresses="SMTP:"+$User["SysAdmin_User_SAM"]+'@sswcom.onmicrosoft.com'}

        $GroupArray = ($User["SysAdmin_User_Groups"] -split ', ')

        foreach($Group in $GroupArray)
        {  
            $GroupString = $Group.Replace('"', '') ## Getting rid of quotes around

            Add-ADPrincipalGroupMembership $User["SysAdmin_User_SAM"] -MemberOf $GroupString  
        } 


        ## Hey Send Email !
    }
}  

##Porvision Skype Account
##Enable Remote User Exchange

Enable-PSRemoting -Force
Invoke-Command -ComputerName SYDADFSP01 -ScriptBlock { Start-ADSyncSyncCycle -PolicyType Delta }