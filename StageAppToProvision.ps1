###
# StageAppToProvision.ps1
# 
# This is a helper script that is run in elevated mode to stage an
# app to the provisioned or OS level.
#
# @Author
# Athit Vue
# 
# @Date
# 6/11/2021
#
# @Last Updated
# 6/30/2021
##

# Retrieving te passed in argument
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

    # Split the folder path into sections. User -leaf param to keep only ending section.
    $SplittedAppName = Split-Path -Path $AppFolderPath -Leaf

    # After elevated script exits check exit code and handle here
    if ($Process.ExitCode -eq 0) {
        $SuccessMessage = "Successfully added the app <$($SplittedAppName)> to the provisioned OS level for new users"
        Write-Host "     $($SuccessMessage).`n" -ForegroundColor Green
        AddToLog $SuccessMessage
    } elseif ($Process.ExitCode -eq 1) {
        $ErrorMessage = "Error: command failed to add <$($SplittedAppName)> app to provisioned OS level."
        Write-Host "     $($ErrorMessage).`n" -ForegroundColor Red 
        AddToLog $ErrorMessage
    } elseif ($Process.ExitCode -eq 2) {
        $ErrorMessage = "Error: success at add/stage to provisioned OS level but failed to update local list"
        Write-Host "     $($ErrorMessage).`n" -ForegroundColor Red
        AddToLog $ErrorMessage
    } elseif ($Process.ExitCode -eq 3) {
        $ErrorMessage = "Error: elevated script failed to do anything."
        Write-Host "     $($ErrorMessage).`n" -ForegroundColor Red
        AddToLog $ErrorMessage
    } else {
        $ErrorMessage = "Error: wow, you have not accounted for this error in the script dude!!!"
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
Function UpdateAppxProvisionPackageLocalList {
    $CurLogInUserWindowsAppsInfoPath = GetCurUserWindowsAppInfoPath
    $FullFilePath = "$CurLogInUserWindowsAppsInfoPath\Provisioned_Apps_List.txt"

    OutputTextExist $FullFilePath

    $ProvisionAppsArray = @()

    try 
    {
        $ProvisionAppsArray = Get-AppxProvisionedPackage -online | Select-Object -ExpandProperty DisplayName
    } 
    catch 
    {
        Write-Host "Error:: UpdateAppXProvisionPackageLocalList(): $_.Exception.Message`n" -ForegroundColor Red
        Write-Host -NoNewLine 'Press any key to continue...';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        return $false
    }

    $Counter = 0

    foreach ($Apps in $ProvisionAppsArray) {
        $Counter += 1  
        # Append app name to text file
        Write-Output $Apps | Out-File -FilePath $FullFilePath -Append
    }
    
    # Append total count to text file 
    Write-Output "" | Out-File -FilePath $FullFilePath -Append
    Write-Output "Total count of provisioned apps available are: <$($Counter)>`n" | Out-File -FilePath $FullFilePath -Append 
    
    # Debugg
    # Write-Host "Done GetAppXProvisionedPackageList`n"

    return $true
}

################# SPECIFIC FUNCTION DEFINITIONS ###############

##
# AppAppToProvisionLevel
# 
# Adds/stage an app to the provisioned OS level for new user on current workstation.
#
# @param <string> AppXBundlePath The full path to the file of the appx bundle
# @return <boolean> True or false base on success or not
Function AddAppToProvisionLevel ($AppxBundlePath) {
    try
    {
        Add-AppxProvisionedPackage -Online -SkipLicense -PackagePath $AppxBundlePath -ErrorAction Inquire
        return $True
    }
    catch 
    {
        $ErrorMessage = "Error:: AddAppToProvisionLevel(): $_.Exception.Message"
        Write-Host "$ErrorMessage`n" -ForegroundColor Red

        AddToLog $ErrorMessage

        Write-Host -NoNewLine 'Press any key to continue...';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

        return $False
    }
}

##################### MAIN ##############################
$CurLoggedInUser = Get-WmiObject -class Win32_ComputerSystem | Select-Object -ExpandProperty Username
$CurLoggedInUserArray = $CurLoggedInUser.split("\")
$CurLoggedInUserName = $CurLoggedInUserArray[1]

$OutputDirectoryPath = "C:\Users\$($CurLoggedInUserName)\Desktop\WindowsAppsInfo"

$AppName = $args[0]
$AppxBundlePath = $args[1]

# Set/stage app to provisioned OS level
$Success1 = AddAppToProvisionLevel $AppxBundlePath

# Get Provisioned (STAGED) apps in the OS level and output to text file. 
$Success2 = UpdateAppxProvisionPackageLocalList

## Debug: to debug uncomment
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