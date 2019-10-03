# SSWCreateADUser
Automatically create AD User, also using Flow.

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
  >5. Sends email on completion

Licenses in Azure are assigned automatically.
