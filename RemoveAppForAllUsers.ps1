###
# RemoveAppForAllUsers.ps1
# 
# This is a helper script that is run in elevated mode to remove an
# app for all users.
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
param($Arg1, $Arg2)

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

    # After elevated script exits check exit code and handle here
    if ($Process.ExitCode -eq 0) {
        $SuccessMessage = "Successfully uninstalled the app <$($Arg2)> for all current users."
        Write-Host "     $($SuccessMessage)`n" -ForegroundColor Green
        AddToLog $SuccessMessage
    } elseif ($Process.ExitCode -eq 1) {
        $ErrorMessage = "Error: command failed to uninstall the app for all current users."
        Write-Host "     $($ErrorMessage)`n" -ForegroundColor Red
        AddToLog $ErrorMessage         
    } elseif ($Process.ExitCode -eq 2) {
        $ErrorMessage = "Error: command failed to update the local list of all uninstalled apps for current user."
        Write-Host "     $($ErrorMessage)`n" -ForegroundColor Red
        AddToLog $ErrorMessage
    } elseif ($Process.ExitCode -eq 3) {
        $ErrorMessage = "Error: elevated script failed to do anything."
        Write-Host "     $($ErrorMessage)`n" -ForegroundColor Red
        AddToLog $ErrorMessage                        
    } 
    else {
        $ErrorMessage = "Error: elevated script failed to do anything."
        Write-Host "     $($ErrorMessage)`n" -ForegroundColor Red
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
# CheckForMoreThanOneApp 
#
# Checks to see if app array contains more than one app.
# If it does, we shouldn't process selected command since we may 
# run into the chance of doing it for other apps that we did not 
# necessarily want to process.
#
# @param <string> InputAppName The app name from user input.
# @return <boolean> True if app array is greater than one. False otherwise.
Function CheckForMoreThanOneApp ($InputAppName) {
    $AppsArray = Get-AppXPackage -AllUsers -Name "*$($InputAppName)*"

    if ($AppsArray.Length -gt 1) {
        Write-Host "     There are more than one app that matches your input of <$($InputAppName)>." -ForegroundColor Red
        Write-Host "     Please use the list below to help you input a more specific app to process:`n" -ForegroundColor Red
        
        $Counter = 0

        foreach ($App in $AppsArray) {
            $Counter += 1
            Write-Host "     $($App)" -ForegroundColor Cyan
        }

        AddToLog "There were more than one match for <$($InputAppName)>."

        Write-Host ""

        Write-Host -NoNewLine 'Press any key to continue...';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        exit 1
    } else {
        return $false
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
        $ErrorMessage = "Error:: UpdateCurrentUserInstalledAppsLocalList(): $_.Exception.Message"
        Write-Host "$($ErrorMessage)`n" -ForegroundColor Red
        AddToLog $ErrorMessage
        Write-Host -NoNewLine 'Press any key to continue...';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        Write-Host "Error: $($_.Exception.Message)"
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
# UninstallAppForAllCurrentUsers
# 
# Uninstalls an app for all current users. 
#
# @param <string> AppName The name of the app to remove for all users. 
# @return <boolean> True or false base on success or not.
Function UninstallAppForAllCurrentUsers ($AppName) {
    $NetworkProfile = Get-NetConnectionProfile | Select-Object -ExpandProperty NetworkCategory

   # try
    #{
       # if ($NetworkProfile -eq "Private"){
       #     Get-AppXPackage -AllUsers -Name "*$($AppName)*" | Remove-AppxPackage
       #     return $True
       # #} elseif ($NetworkProfile -eq "domain") {
      #try
      #{
      #     Get-AppXPackage -Name "*$($AppName)*" | Remove-AppxPackage
      #}
      #catch
      #{
      #     $ErrorMessage = "Error:: UninstallAppForAllCurrentUsers(): $_.Exception.Message"
      #     Write-Host "$($ErrorMessage)`n" -ForegroundColor Red
      #     AddToLog $ErrorMessage
      #     Write-Host -NoNewLine 'Press any key to continue...';
      #     $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
      #      
      #     return $False
      #}

       try
       {
            Get-AppXPackage -AllUsers -Name "*$($AppName)*" | Remove-AppxPackage -AllUsers
       }
       catch
       {
            $ErrorMessage = "Error:: UninstallAppForAllCurrentUsers(): $_.Exception.Message"
            Write-Host "$($ErrorMessage)`n" -ForegroundColor Red
            AddToLog $ErrorMessage
            Write-Host -NoNewLine 'Press any key to continue...';
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
             
            return $False
       } 
            

        return $True
       # }
  # }
  # catch
  # {
  #     Write-Host "Error:: UninstallAppForAllCurrentUsers: $_.Exception.Message`n" -ForegroundColor Red
  #     Write-Host -NoNewLine 'Press any key to continue...';
  #     $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
  #     
  #     return $False
  # }
}

##################### MAIN ##############################

$OutputDirectoryPath = "$env:USERPROFILE\Desktop\WindowsAppsInfo"

$AppName = $args[0]

CheckForMoreThanOneApp $AppName 

$Success1 = UninstallAppForAllCurrentUsers $AppName
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