###
# InstallDependencies.ps1
# 
# This is a helper script that is run in elevated mode to remove an
# add dependencies for an app. 
#
# @Author
# Athit Vue
# 
# @Date
# 6/28/2021
#
# @Last Updated
# 6/28/2021
##

# Retrieving the passed in argument
param($Arg1, $Arg2)

# Set the argument to array variable
$args = @($Arg1, $Arg2)

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
        Write-Host "Error:: UpdateCurrentUserInstalledAppsLocalList: $_.Exception.Message`n" -ForegroundColor Red
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
# InstallDependencies
# 
# Set location to the folder of dependencies and installs them 
# one at a time.
#
# @param <string> AppFolderPath The path to the app folder.
# @param <string> OutputDirectoryPath The directory for the log file. 
Function InstallDependencies ($AppDependencyPath, $OutputDirectoryPath) {
    try
    {
        [array]$DependencyPaths = Get-ChildItem -Path $AppDependencyPath -Name -File
    }
    catch
    {
        $ErrorMessage = "Error:: InstallDependencies(): $_.Exception.Message`n" 
        AddToLog $ErrorMessage
        Write-Host "     $ErrorMessage" -ForegroundColor Red
        return $False
    }

    try
    {
        Set-Location $AppDependencyPath
    }
    catch
    {
        $ErrorMessage = "Error:: InstallDependencies(): $_.Exception.Message`n" 
        AddToLog $ErrorMessage
        Write-Host "     $ErrorMessage" -ForegroundColor Red
        return $False    
    }

    foreach ($DependencyFilePath in $DependencyPaths) {
        if (($DependencyFilePath -like "*.appxbundle") -Or ($DependencyFilePath -like "*.msixbundle") -Or ($DependencyFilePath -like "*.appx")) {
                            
            $InstallingMessage = "Installing dependency <$($DependencyFilePath)>..."
            AddToLog $InstallingMessage
            Write-Host "     $($InstallingMessage)" -ForegroundColor Cyan
                            
            try 
            {
                Add-AppxPackage -Path ".\$($DependencyFilePath)"
                $SuccessMessage = "Successfully install the dependency <$($DependencyFilePath)>!"
                AddToLog $SuccessMessage
                Write-Host "     $($SuccessMessage)" -ForegroundColor Green

            }
            catch
            {
                $ErrorMessage = "Error:: InstallDependency(): $_.Exception.Message"  
                AddToLog $ErrorMessage
                Write-Host "     $($ErrorMessage)`n" -ForegroundColor Red 
                return $False
            }
        }
    }

    write-host ""
    return $True
}
##################### MAIN ##############################

$OutputDirectoryPath = "$env:USERPROFILE\Desktop\WindowsAppsInfo"

$AppName = $args[0]
$DependencyWorkDir = $args[1]

$Success1 = InstallDependencies $DependencyWorkDir $OutputDirectoryPath
$Success2 = UpdateCurrentUserInstalledAppsLocalList

$QuitResponse = ""
while($QuitResponse -ne "q" -or $QuitResponse -ne "Q") {
   Write-Host "     Enter q to continue: " -NoNewline
   $QuitResponse = Read-Host
}

if (!($Success1) -and !($Success2)) {
    exit 3
} elseif (!($Success2)) {
    exit 2
} elseif (!($Success1)) {
    exit 1
} 