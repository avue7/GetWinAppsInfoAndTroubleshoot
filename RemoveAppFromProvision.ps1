###
# RemoveAppFromProvision.ps1
# 
# This is a helper script that is run in elevated mode to remove an
# app from the provisioned or OS level.
#
# @Author
# Athit Vue
# 
# @Date
# 6/13/2021
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
        Write-Host "Error: UpdateAppXProvisionPackageLocalList: $_.Exception.Message`n" -ForegroundColor Red
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
# GetPackageName
# 
# Gets the package name of the app to remove at the provisioned level. 
#
# @param <string> AppName The name of the app to remove.
# @return <string> AppPackageName The package name of the app to be removed or "NONE" failed.
Function GetPackageName ($AppName) {
    try
    {
        $AppPackageName = Get-AppxProvisionedPackage -Online | Where-Object {$_.PackageName -like "*$($AppName)*"} | Select-Object -ExpandProperty PackageName
        return $AppPackageName
    }
    catch
    {
        # If we wanted to know exactly why it did not go thru we can catch and display the error returned here.
        # What we can do is make this script pause and wait for user to prompt exiting script so that the 
        # user can at least see what the error message return is before going back to the calling script. 
        # For simplicity, well just return false and parse it at the main script without getting the 
        # actual error. Keep this block and next line for future implementation if needed.
        Write-Host "Error:: GetPackageName: $_.Exception.Message`n" -ForegroundColor Red
        Write-Host -NoNewLine 'Press any key to continue...';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        
        return "ERROR"
    }
}

##
# RemoveAppFromProvisionLevel
# 
# Removes an app from the provisioned OS level for new user on current workstation.
#
# @param <string> AppPackageName The package name of the app to be removed.
# @return <boolean> True or false base on success or not
Function RemoveAppFromProvisionLevel ($AppPackageName) {
    try
    {
        Remove-AppxProvisionedPackage -Online -PackageName $AppPackageName
        return $True
    }
    catch 
    {
        Write-Host "Error:: RemoveAppFromProvisionLevel: $_.Exception.Message`n" -ForegroundColor Red
        Write-Host -NoNewLine 'Press any key to continue...';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

        return $False
    }
}

##################### MAIN ##############################

$OutputDirectoryPath = "$env:USERPROFILE\Desktop\WindowsAppsInfo"

$AppName = $args[0]

$AppPackageName = GetPackageName $AppName

# Exit with code 5 if not found. No point continuing. Caller will 
# handle code.
if ($($AppPackageName) -eq "" -or $AppPackageName -eq $null) {
    exit 5   
}

# Remove app to provisioned OS level
$Success2 = RemoveAppFromProvisionLevel $AppPackageName

# Get Provisioned (STAGED) apps in the OS level and output to text file. 
$Success3 = UpdateAppxProvisionPackageLocalList

# Debug: to debug uncomment
#$QuitResponse = ""
#while($QuitResponse -ne "q") {
#   Write-Host "quit or not: " -NoNewline
#   $QuitResponse = Read-Host
#}

if (($AppPackageName -eq "ERROR") -and !($Success2) -and !($Success3)) {
    exit 4
} elseif (!($Success3)) {
    exit 3
} elseif (!($Success2)) {
    exit 2
} elseif ($AppPackageName -eq "ERROR") {
    exit 1
} 