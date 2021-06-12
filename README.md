# GetWinAppsInfoAndTroubleshoot
This is an interactive powershell script that does the following:
1. Created a new directory on the current logged in user's desktop.
2. In this directory, when the script is run, it creates 3 files that shows information about Windows Native Apps (UWP).
3. User interaction:&nbsp;
   a. Uninstall and reinstall an app. &nbsp;
   b. Install/reinstall an app without uninstalling. &nbsp;
   c. Checks to see if app is installed for current user. &nbsp;
   d. Remove and app for current user. &nbsp;
   
   (Options below will affect all users or new users) &nbsp;
   e. Uninstall an app for all users on current workstation. &nbsp;
   e. Check if app is staged at the provisioned OS level for new users on current workstation or computer. &nbsp;
   f. Stage an app at provisioned OS level for new users of current workstation or computer. (TODO) &nbsp;
   g. Uninstall/unstage an app for the provisioned OS level for new users. &nbsp;
 
 For elevated commands within the current user's context, I've found creating another script and having it run and finish
 was the more ideal solution here. Thus the main script is the GetWindowsAppInfoAndTroubleshoot.ps1 and the helper script is
 the GetAppsInfo.ps1. Both of these files must be in the same directory, but can located just about anywhere on the workstation.
