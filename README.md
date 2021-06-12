# GetWinAppsInfoAndTroubleshoot
This is an interactive powershell script that does the following:
1. Created a new directory on the current logged in user's desktop.
2. In this directory, when the script is run, it creates 3 files that shows information about Windows Native Apps (UWP).
3. User interaction:<br />
   a. Uninstall and reinstall an app.<br />
   b. Install/reinstall an app without uninstalling.<br />
   c. Checks to see if app is installed for current user. <br />
   d. Remove and app for current user.<br />
   
   (Options below will affect all users or new users)<br />
   e. Uninstall an app for all users on current workstation. <br />
   e. Check if app is staged at the provisioned OS level for new users on current workstation or computer. <br />
   f. Stage an app at provisioned OS level for new users of current workstation or computer. (TODO) <br />
   g. Uninstall/unstage an app for the provisioned OS level for new users. <br />
 
 For elevated commands within the current user's context, I've found creating another script and having it called from the 
 current user's context was the more ideal solution here. Thus the main script is the GetWindowsAppInfoAndTroubleshoot.ps1 
 and the helper script that runs in elevated mode is the GetAppsInfo.ps1. Both of these files must be in the same directory,
 but can located just about anywhere on the workstation.
