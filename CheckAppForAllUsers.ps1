###
# CheckjAppForAllUsers.ps1
# 
# This is a helper script that is run in elevated mode to query 
# the users the app is installed for.
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
# UpdateLocalPackageUserInformation 
#
# Gets provisioned app packages staged at OS level and outputs 
# name to a text in the documents directory. 
# 
# @param <string> PackageUserInformation The package information for the user it is installed for. 
# @return <boolean> True or false base on success. 
Function UpdateLocalPackageUserInformation ($PackageUserInformation) {
    $CurLogInUserWindowsAppsInfoPath = GetCurUserWindowsAppInfoPath
    $FullFilePath = "$CurLogInUserWindowsAppsInfoPath\All_Users_App_Search.txt"

    OutputTextExist $FullFilePath
    
    try 
    {
        foreach ($Info in $PackageUserInformation) {
            Write-Output "$($Info)" | Out-File -FilePath $FullFilePath -Append
        }

        return $True
    }
    catch 
    {
        Write-Host "Error:: UpdateLocalPackageUserInformation: $_.Exception.Message`n" -ForegroundColor Red
        Write-Host -NoNewLine 'Press any key to continue...';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        return $False
    }
}

################# SPECIFIC FUNCTION DEFINITIONS ###############

##
# GetUsersAppIsInstalledFor
# 
# Gets the PackageUserInformation for the users that an app is currently
# installed for.
#
# @param <string> AppName The name of the app to search for. 
# @return <array> $PackageUserInfomationArray Returns array or string "NONE"
Function GetUsersAppIsInstalledFor ($AppName) {
    try
    {
        $PackageUserInformationArray = Get-AppxPackage -AllUser -Name "*$($AppName)*" | Select-Object -ExpandProperty PackageUserInformation
        return $PackageUserInformationArray
    }
    catch
    {
        Write-Host "Error:: GetUserAppIsInstalledFor: $_.Exception.Message`n" -ForegroundColor Red
        Write-Host -NoNewLine 'Press any key to continue...';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        
        return "NONE"
    }
}

##################### MAIN ##############################

$OutputDirectoryPath = "$env:USERPROFILE\Desktop\WindowsAppsInfo"

$AppName = $args[0]

$PackageUserInfo = GetUsersAppIsInstalledFor $AppName

Write-Host "Packinfo : $PackageUserInfo"

$Success2 = $False

# Debug: to debug uncomment
$QuitResponse = ""
while($QuitResponse -ne "q") {
   Write-Host "quit or not: " -NoNewline
   $QuitResponse = Read-Host
}

if (($PackageUserInfo -eq $NULL) -or ($PackageUserInfo -eq "NONE")) {
    Exit 1
} else {
    $Success2 = UpdateLocalPackageUserInformation $PackageUserInfo
    
    if ($Success2 -eq $False) {
        Exit 2
    }
}
