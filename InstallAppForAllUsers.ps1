###
# InstallAppForAllUsers.ps1
# 
# This is a helper script that is run in elevated mode to install an
# app for all current users of the workstation.
#
# @Author
# Athit Vue
# 
# @Date
# 6/14/2021
#
# @Last Updated
# 6/14/2021
##

# Retrieving the passed in argument
param($Arg1)

# Set the argument to array variable
$args = @($Arg1)

######################### SELF-ELEVATE ###########################

# BOILER PLATE CODE BLOCK:
# Self-elevated mode. Basically checks to see if current user
# is an admin. If not, then exit non-elevated and opens 
# new process in elevatd mode with program selected at "FilePath".
# If you have arguments passed to pass to this script from the 
# calling script, declare and set them to the array variable 
# "$args". 
if (!
	#current role
	(New-Object Security.Principal.WindowsPrincipal(
		[Security.Principal.WindowsIdentity]::GetCurrent()
	#is admin?
	)).IsInRole(
		[Security.Principal.WindowsBuiltInRole]::Administrator
	)
) {
	#elevate script and exit current non-elevated runtime
	$Process = Start-Process `
		-FilePath 'powershell' `
		-ArgumentList (
			#flatten to single array
			'-File', $MyInvocation.MyCommand.Source, $args `
			| %{ $_ }
		) `
		-Verb RunAs -PassThru -Wait

    ## After elevated script exits check exit code and handle here
    if ($Process.ExitCode -eq 0) {
        $SuccessMessage = "Successfully Install/Reinstall the app for all current users."
        Write-Host "     $($SuccessMessage)`n" -ForegroundColor Green
        AddToLog $SuccessMessage
    } elseif ($Process.ExitCode -eq 1) {
        $ErrorMessage = "Error: command failed to install/reinstall the app for all current users."
        Write-Host "     $($ErrorMessage)`n" -ForegroundColor Red 
        AddToLog $ErrorMessage
    } elseif ($Process.ExitCode -eq 2) {
        $ErrorMessage = "Error: command failed to update the local list of all installed apps for current user."
        Write-Host "     $($ErrorMessage)`n" -ForegroundColor Red
    } elseif ($Process.ExitCode -eq 3) {
        $ErrorMessage = "Error: elevated script failed to do anything."
        Write-Host "     $ErrorMessage`n" -ForegroundColor Red  
        AddToLog $ErrorMessage              
    } 
    else {
        $ErrorMessage = "Error: wow, something is wrong in the script itself!!!"
        Write-Host "     $ErrorMessage`n" -ForegroundColor Red
        AddToLog $ErrorMessage
    }

	exit $Process.ExitCode
}

###################### BOILER PLATE FUNCTIONS #####################

## 
# OutputTextExist
#
# I have not found a better way to delete if exist while appending to 
# a text file. Feel free to modify if you find a better way.
#
# @Param <string> FullPath The full path to file to delete.
Function OutputTextExist ($FullPath) {
    if (Test-Path -Path $FullPath) {
        Remove-Item -Path $FullPath
    }
}

##
# AddToLog
#
# Adds message to log file.
# 
# @param <string> Message The message to add to the log file.
Function AddToLog ($Message) {
    $CurLogInUserWindowsAppsInfoPath = GetCurUserWindowsAppInfoPath
    $LogFilePath = "$CurLogInUserWindowsAppsInfoPath\Log.txt"
    $DateTime = Get-Date
    $MessageWithDateTime = "- $($DateTime): $($Message)"

    if (($Message -ne $NULL) -or ($Message -ne "")) {
        Write-Output $MessageWithDateTime | Out-File -FilePath $LogFilePath -Append
    }
}

##
# GetCurUserWindowsAppInfoPath
# 
# Gets the semi hard coded path to the WindowsAppInfo folder. 
# We need this to be able to write to the folder in context of the currently  
# logged in user since we are in the admin context.
#
# @return <string> CurLogInUserFullDesktopPath The full path to the user's WindowsAppsInfo directory.
Function GetCurUserWindowsAppInfoPath {
    $CurLogInUserFull = Get-WmiObject -class Win32_ComputerSystem | Select-Object -ExpandProperty Username
    $CurLogInUserArray = $CurLogInUserFull.split("\")
    $CurLogInUserName = $CurLogInUserArray[1]

    $CurLogInUserFullDesktopPath = "C:\Users\$($CurLogInUserName)\Desktop\WindowsAppsInfo"

    return $CurLogInUserFullDesktopPath
}

## 
# UpdateAppxProvisionPackageLocalList 
#
# Gets provisioned app packages staged at OS level and outputs 
# name to a text in the documents directory. 
# 
# @return <boolean> True or false base on success. 
Function UpdateCurrentUserInstalledAppsLocalList {
    $CurLogInUserWindowsAppsInfoPath = GetCurUserWindowsAppInfoPath
    $FullFilePath = "$CurLogInUserWindowsAppsInfoPath\Current_User_Installed_Apps_List.txt"

    OutputTextExist $FullFilePath

    $InstalledAppsArray = @()

    try 
    {
        $InstalledAppsArray = Get-AppxPackage | Select-Object -ExpandProperty Name
    }
    catch 
    {
        $ErrorMessage = "Error:: UpdateCurrentUserInstalledAppsLocalList: $_.Exception.Message"
        Write-Host "$($ErrorMessage)`n" -ForegroundColor Red
        Write-Host -NoNewLine 'Press any key to continue...';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        return $false  
    }

    $Counter = 0

    foreach ($Apps in $InstalledAppsArray) {
        $Counter += 1  
        # Append app name to text file
        Write-Output $Apps | Out-File -FilePath $FullFilePath -Append
    }
    
    Write-Output "" | Out-File -FilePath $FullFilePath -Append
    Write-Output "Total count of apps installed under current user <$($CurLoggedInUser)>: <$($Counter)>" | Out-File -FilePath $FullFilePath -Append 

    return $true
}

################# SPECIFIC FUNCTION DEFINITIONS ###############

##
# InstallAppForAllCurrentUsers
# 
# Installs/reinstall an app for all current users. 
#
# @param <string> AppName The name of the app to remove for all users. 
# @return <boolean> True or false base on success or not.
Function InstallAppForAllCurrentUsers ($AppName) {
    try
    {
        Get-AppxPackage -AllUser -Name "*$($AppName)*" | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"}
        return $True
    }
    catch
    {
        $ErrorMessage = "Error:: InstallAppForAllCurrentUsers: $_.Exception.Message"
        Write-Host "$($ErrorMessage)`n" -ForegroundColor Red
        AddToLog $ErrorMessage
        Write-Host -NoNewLine 'Press any key to continue...';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        
        return $False
    }
}

##################### MAIN ##############################

$OutputDirectoryPath = "$env:USERPROFILE\Desktop\WindowsAppsInfo"

$AppName = $args[0]

$Success1 = InstallAppForAllCurrentUsers $AppName
$Success2 = UpdateCurrentUserInstalledAppsLocalList

# Debug: to debug uncomment
#$QuitResponse = ""
#while($QuitResponse -ne "q") {
#   Write-Host "quit or not: " -NoNewline
#   $QuitResponse = Read-Host
#}

if (!($Success1) -and !($Success2)) {
    exit 3
} elseif (!($Success2)) {
    exit 2
} elseif (!($Success1)) {
    exit 1
} 