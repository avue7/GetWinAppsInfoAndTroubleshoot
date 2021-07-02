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

        ## After elevated script exits check exit code and handle here
        if ($Process.ExitCode -eq 0) {
           # Display the app on the list show it here. 
           $AppInfoFilePath = "$($OutputDirectoryPath)\All_Users_App_Search.txt"
           
           try
           {
                $AppsInfoArray = Get-Content $AppInfoFilePath
           }
           catch
           {
                $ErrorMessage = "Error:: could not get All_Users_App_Search: $_.Exception.Message"
                AddToLog $ErrorMessage
                Write-Host "     $($ErrorMessage)`n" -ForegroundColor Red
                exit $Process.ExitCode
           }
      
           $SuccessMessage = "Found! The following app(s) matched your input and is installed for user(s):"
           Write-Host "     $($SuccessMessage)`n" -ForegroundColor Green

           AddToLog $SuccessMessage

           foreach ($UserInfo in $AppsInfoArray) {
               $Counter += 1
               Write-Host "     $($UserInfo)" -ForegroundColor Yellow
               AddToLog $UserInfo    
           }
            Write-Host ""
        } elseif ($Process.ExitCode -eq 1) {
            $ErrorMessage = "Not found! No installed app matched <$UserPrompt>."
            Write-Host "     $($ErrorMessage)`n" -ForegroundColor Red
            AddToLog $ErrorMessage 
        } elseif ($Process.ExitCode -eq 2) {
            $ErrorMessage = "Error: command failed to search the app for all current users."
            Write-Host "     $($ErrorMessage)`n" -ForegroundColor Red
        } elseif ($Process.ExitCode -eq 3) {
            $ErrorMessage = "Error: command failed to redirect to output file."
            Write-Host "     $($ErrorMessage)`n" -ForegroundColor Red
        }  
        else {
            $ErrorMessage = "Error: wow, something is wrong in the script itself!!!"
            Write-Host "     $($ErrorMessage)`n" -ForegroundColor Red
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
# UpdateLocalPackageUserInformation 
#
# Gets provisioned app packages staged at OS level and outputs 
# name to a text in the documents directory. 
# 
# @param <string> PackageUserInformation The package information for the user it is installed for. 
# @return <boolean> True or false base on success. 
Function UpdateLocalPackageUserInformation ($PackageUserAppInfo) {
    $CurLogInUserWindowsAppsInfoPath = GetCurUserWindowsAppInfoPath
    $FullFilePath = "$CurLogInUserWindowsAppsInfoPath\All_Users_App_Search.txt"

    OutputTextExist $FullFilePath
    
    $Counter = 0

    foreach ($AppName in $PackageUserAppInfo.keys) {
        $Counter += 1

        try
        {
            Write-Output "$($Counter). $($AppName)" | Out-File -FilePath $FullFilePath -Append
        }
        catch 
        {
            $ErrorMessage = "Error:: UpdateLocalPackageUserInformation(): $_.Exception.Message"
            Write-Host "$($ErrorMessage)`n" -ForegroundColor Red
            AddToLog $ErrorMessage
            Write-Host -NoNewLine 'Press any key to continue...';
            $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
            return $False
        }

        if ("$($PackageUserAppInfo[$AppName])" -like "*Installed S*") {
            $SplitArray = $($PackageUserAppInfo[$AppName]) -Split "installed "
            
            foreach ($User in $SplitArray) {
                try
                {
                    Write-Output "$($User)" | Out-File -FilePath $FullFilePath -Append
                }
                catch 
                {
                    $ErrorMessage = "Error:: UpdateLocalPackageUserInformation(): $_.Exception.Message"
                    Write-Host "$($ErrorMessage)`n" -ForegroundColor Red
                    AddToLog $ErrorMessage
                    Write-Host -NoNewLine 'Press any key to continue...';
                    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
                    return $False
                }
                
            }
            
        } else {
            try
            {
                Write-Output "$($PackageUserAppInfo[$AppName])" | Out-File -FilePath $FullFilePath -Append
            }
            catch 
            {
                $ErrorMessage = "Error:: UpdateLocalPackageUserInformation(): $_.Exception.Message"
                Write-Host "$($ErrorMessage)`n" -ForegroundColor Red
                AddToLog $ErrorMessage
                Write-Host -NoNewLine 'Press any key to continue...';
                $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
                return $False
            }
        }
        Write-Output "" | Out-File -FilePath $FullFilePath -Append    
    }

    return $True
}

################# SPECIFIC FUNCTION DEFINITIONS ###############

##
# GetUsersAppIsInstalledFor
# 
# Gets the PackageUserInformation for the users that an app is currently
# installed for.
#
# @param <string> AppName The name of the app to search for. 
# @return <dictionary> $PackageUserInfomationArray Returns array or string "NONE"
Function GetUsersAppIsInstalledFor ($AppName) {
    try
    {
        $PackageUserInfoArray = Get-AppxPackage -AllUser -Name "*$($AppName)*" | Where-Object {$_.PackageUserInformation -like "*installed*"}
    }
    catch
    {
        $ErrorMessage = "Error:: GetUserAppIsInstalledFor(): $_.Exception.Message"
        Write-Host "$($ErrorMessage)`n" -ForegroundColor Red
        Write-Host -NoNewLine 'Press any key to continue...';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        AddToLog $ErrorMessage
        return "NONE"
    }

    $PackageInfoDictionary = @{}

    if ($PackageUserInfoArray -ne $Null) {
        foreach ($PackageInfo in $PackageUserInfoArray) {
            $User = $PackageInfo | Select-Object -ExpandProperty PackageUserInformation
            $AppName = $PackageInfo | Select-Object -ExpandProperty PackageFullName
            $PackageInfoDictionary.Add($AppName, $User)
        }
        
        return $PackageInfoDictionary
    }
}

##################### MAIN ##############################

$OutputDirectoryPath = "$env:USERPROFILE\Desktop\WindowsAppsInfo"

$AppName = $args[0]

$PackageUserAppDict = GetUsersAppIsInstalledFor $AppName

$Success2 = $False

# Debug: to debug uncomment
#$QuitResponse = ""
#while($QuitResponse -ne "q") {
#   Write-Host "quit or not: " -NoNewline
#   $QuitResponse = Read-Host
#}

if ($PackageUserAppDict -eq $NULL) {
    Exit 1
} elseif ($PackageUserAppDict -eq "NONE") {
    Exit 2
} else {
    $Success2 = UpdateLocalPackageUserInformation $PackageUserAppDict
    if ($Success2 -eq $False) {
        Exit 3
    }
}
