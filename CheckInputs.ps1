## Connects to SharePoint Online
Connect-PnPOnline -Url https://sswcom.sharepoint.com/sysadmin

#Defines List name in SharePoint
$ListName = "New AD User"

$UserList = (Get-PnPListItem -List $ListName -Fields "Title","SysAdmin_User_Name", "SysAdmin_User_GivenName","SysAdmin_User_Surname","SysAdmin_User_DisplayName","SysAdmin_User_Office",
"SysAdmin_User_Email","SysAdmin_User_Street","SysAdmin_User_City","SysAdmin_User_State", "SysAdmin_User_PostCode","SysAdmin_User_MobilePhone","SysAdmin_User_JobTitle","SysAdmin_User_Manager", 
"SysAdmin_User_OU","SysAdmin_User_SAM","SysAdmin_User_Created","SysAdmin_User_Groups","SysAdmin_User_Country")


foreach($User in $UserList)
{  
    if ($User["SysAdmin_User_Created"] -eq $false)
    {
        Write-Host " "$User["Title"]" "$User["SysAdmin_User_Name"]" "$User["SysAdmin_User_GivenName"]" "$User["SysAdmin_User_Surname"]" "$User["SysAdmin_User_DisplayName"]" "$User["SysAdmin_User_Office"]" "$User["SysAdmin_User_Email"]" "$User["SysAdmin_User_Street"]" "$User["SysAdmin_User_City"]" "$User["SysAdmin_User_State"]" "$User["SysAdmin_User_PostCode"]" "$User["SysAdmin_User_MobilePhone"]" "$User["SysAdmin_User_JobTitle"]" "$User["SysAdmin_User_Manager"]" "$User["SysAdmin_User_OU"]" "$User["SysAdmin_User_SAM"]" "$User["SysAdmin_User_Created"]" "$User["SysAdmin_User_Groups"]")"
    }
}  
