# SSWCreateADUser
Automatically create AD User on premises.

1. User fills in Microsoft Forms which triggers a flow
2. Flow runs
  >1. Checks user details against Azure and populates a SharePoint list
  >2. Creates and deletes a file on premises
3. Filewatcher service initiates a powershell script
4. Powershell runs
  >1. Creates AD User
  >2. Forces AD Sync to AAD
  >3. Enables Remote Mailbox
  >4. Creates Skype Account
  >5. Updates SharePoint SysAdmin_User_Created to $true
  >6. Sends email on completion
5. AAD Connect assigns a location using AD Attribute 'c'
6. O365 Licenses assigned automatically

* Documentation can be found: https://sswcom.sharepoint.com/SysAdmin/SharedDocuments/Forms/AllItems.aspx?RootFolder=%2FSysAdmin%2FSharedDocuments%2FActive%20Directory
* High level overview: TODO: ADD VIDEO
* PowerShell Walkthrough: TODO: ADD VIDEO
