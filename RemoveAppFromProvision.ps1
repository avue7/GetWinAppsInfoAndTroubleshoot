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
# 6/30/2021
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
    
    # After elevated script exits check exit code and handle here
    if ($Process.ExitCode -eq 0) {
        #$FoundAppName = Get-Variable -Name ProAppName
        $SuccessMessage = "Successfully deleted the app <$($UserPrompt)> from the provisioned OS level for new users."
        Write-Host "     $SuccessMessage`n" -ForegroundColor Green
        AddToLog $SuccessMessage
    } elseif ($Process.ExitCode -eq 1) {
        $ErrorMessage = "Error: command failed to package name for <$($UserPrompt)>."
        Write-Host "     $ErrorMessage`n" -ForegroundColor Red 
        AddToLog $ErrorMessage
    } elseif ($Process.ExitCode -eq 2) {
        $ErrorMessage = "Error: command failed to remove package from provisioned OS level."
        Write-Host "     $ErrorMessage`n" -ForegroundColor Red
        AddToLog $ErrorMessage
    } elseif ($Process.ExitCode -eq 3) {
        $ErrorMessage = "Error: elevated script failed to do anything."
        Write-Host "     $ErrorMessage`n" -ForegroundColor Red   
        AddToLog $ErrorMessage             
    } elseif ($Process.ExitCode -eq 4) {
        $ErrorMessage = "Error: elevated script failed to do anything."
        Write-Host "     $ErrorMessage`n" -ForegroundColor Red
        AddToLog $ErrorMessage
    } elseif ($Process.ExitCode -eq 5) {
        $ErrorMessage = "Not Found! There are no matches for <$($UserPrompt)> staged at the provisioned OS level."
        Write-Host "     $ErrorMessage`n" -ForegroundColor Red
        AddToLog $ErrorMessage
    } elseif ($Process.ExitCode -eq 6) {
        break
    } else {
        $ErrorMessage = "Error: wow, something is wrong with the script iteself!!!"
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
        $ErrorMessage = "Error:: GetPackageName(): $_.Exception.Message"
        Write-Host "$ErrorMessage`n" -ForegroundColor Red
        AddToLog $ErrorMessage
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
        $ErrorMessage = "Error:: RemoveAppFromProvisionLevel(): $_.Exception.Message"
        Write-Host "$ErrorMessage`n" -ForegroundColor Red
        AddToLog $ErrorMessage
        Write-Host -NoNewLine 'Press any key to continue...';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

        return $False
    }
}

##################### MAIN ##############################

$OutputDirectoryPath = "$env:USERPROFILE\Desktop\WindowsAppsInfo"

$AppName = $args[0]

$PromptYN = "y"
$Counter = 0

While (($PromptYN -eq "y") -or ($PromptYN -eq "Y")) {
    if ($Counter -ge 1) {
        Write-Host "     Enter the full app name to remove from the provisioned OS level: " -NoNewline
        $AppName = Read-Host
    }

    [array]$AppPackageName = GetPackageName $AppName

    if ($AppPackageName.Length -lt 1) {
        exit 5
    } elseif ($AppPackageName.Length -gt 1) {
        Write-Host "     There are more than one app that matches your input of <$($AppName)>." -ForegroundColor Red
        Write-Host "     Please use the list below to help you input a more specific app to process:`n" -ForegroundColor Red

        $Counter2 = 0
        foreach ($App in $AppPackageName) {
            $Counter2 += 1
            Write-Host "     $($Counter2). $($App)" -ForegroundColor Cyan
        }

        write-Host ""

        Write-Host "     Would you like to re-try (y/n): " -NoNewline
        $PromptYN = Read-Host
        Write-Host " "

        if (($PromptYN -eq "n") -or ($PromptYN -eq "N")) {
            AddToLog "User escaped..."
            Exit 6
        }
    } else {
        break
    }

    $Counter += 1
}


# Exit with code 5 if not found. No point continuing. Caller will 
# handle code.
if ($($AppPackageName) -eq "" -or $AppPackageName -eq $null) {
    exit 5   
}

#Set-Variable -Name ProAppName -Value "$($AppPackageName[0])" -Scope 1

# Remove app to provisioned OS level
$Success2 = RemoveAppFromProvisionLevel $AppPackageName[0]

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