###
# GetWindowsAppInfoAndTroubleShoot.ps1
#
# @Description:
# This script is to test what Universal Windows Platform (UWP) apps are currently on the workstation at the OS level and local user level.
# The two methods invoked below will write to host and append any apps that are staged globally and installed at the local level to a directory 
# (created by this script if not exists) at the root C directory. This directory will be named "WindowsAppsInfo" and will be created at the current
# user's desktop for easier access and removal after you are done querying.
# 
# @Author:
# Athit Vue
#
# @Date:
# 6/1/2021 
#
# @Last Updated:
# 6/14/2021
##

######################### GLOABL VARIABLES ############################
$CurLoggedInUser = Get-WmiObject -class Win32_ComputerSystem | Select-Object -ExpandProperty Username
$CurLoggedInUserArray = $CurLoggedInUser.split("\")
$CurLoggedInUserName = $CurLoggedInUserArray[1]
$CurWorkstationName = $CurLoggedInUserArray[0]

$CurWorkingDir = Get-Location | Select-Object -ExpandProperty Path

$AppXBundleDir = "$($CurWorkingDir)\AppXBundles\"
$OutputDirectoryPath = "$env:USERPROFILE\Desktop\WindowsAppsInfo"
$ProAppListName = "Provisioned_Apps_List.txt"

######################### FUNCTION DEFINITIONS GOES HERE ################################

##
# AppTestOUtputDirExist
#
# Checks to see if output directory exists. 
# If not exists, create it.
# 
Function AppTestOUtputDirExist {
    if (!(Test-Path -Path "$OutputDirectoryPath")) {
        try 
        {
            # Create new directory and pipe out to null for silent creation
            New-Item -ItemType Directory -Path $OutputDirectoryPath | Out-Null
            Write-Host "`nSuccessfully created the <$($OutputDirectoryPath)> directory.`n" -ForegroundColor Green
            AddToLog "Successfully created the <$($OutputDirectoryPath)> directory.`n"
        }
        catch
        {
            $ErrorMessage = "Error:: AppTestOutputDirExist: failed to create <$($OutputDirectoryPath)> : $($_.Exeption.Message)`n"
            AddToLog $ErrorMessage
            Write-Host "`n$($ErrorMessage)"
        }
    }
}

##
# OutputTextExist
#
# If output text exist, delete. We don't want redundant data.
# I have not found a better way to delete if exist while appending to 
# a text file. Feel free to modify if you find a better way.
#
# @Param <string> FullPath The full path to file to delete.
Function OutputTextExist ($FullPath) {
    if (Test-Path -Path $FullPath) {
        try 
        {
            Remove-Item -Path $FullPath     
        }
        catch
        {
            $ErrorMessage = "     Error: OutputTextExist: $($_.Exception.Message)`n"
            AddToLog $ErrorMessage
            Write-Host $ErrorMessage
        }
    }
}

## 
# GetAppsInfo
#
# Gets provisioned app packages staged at OS level and apps available to
# current user. Then outputs apps' names to a text for each category. 
function GetAppsInfo {
    $CurrentWorkingDirectory = Get-Location | Select-Object -ExpandProperty Path
    $FilePath = "$($CurrentWorkingDirectory)\GetAppsInfo.ps1"

    # Start a new process of powershell in elevated mode to run the get provisioned package command
    $Process = Start-Process Powershell -ArgumentList "-File $($FilePath)" -Verb RunAs -PassThru -Wait

    # Debugg:
    # Write-Host $Process.ExitCode
   
   # Please keep for future use 
   #if ($Process.ExitCode -eq "3") {
   #    Write-Host "`nError: The script in elevated mode failed to get any info on apps at all.`n" -ForegroundColor Red
   #    Write-Host "No worries, please continue...`n" -ForegroundColor Red
   #    return
   #} else {
        if ($Process.ExitCode -eq "1") {
            Write-Host "`nError: The script in elevated mode failed to get the provisioned apps list.`n" -ForegroundColor Red
            Write-Host "No worries, please continue...`n" -ForegroundColor Red
        } else {
            GetAppxProvisionPackageList $OutputDirectoryPath
        }
        
       #if ($Process.ExitCode -eq "2"){
       #    Write-Host "`nError: The script in elevated mode failed to get the staged apps list.`n" -ForegroundColor Red
       #    Write-Host "No worries, please continue...`n" -ForegroundColor Red
       #} else {
       #    GetStagedAppXPackageList $OutputDirectoryPath
       #}
    #}

    # Show user what apps we have available in the appxbundle

}

## 
# GetAppXProvisionPackageList 
#
# Outputs provisioned apps list. 
# 
# @Param <string> OutputDirectoryPath The path of the output directory. 
Function GetAppxProvisionPackageList {
    $FullFilePath = "$($OutputDirectoryPath)\$($ProAppListName)"    
    
    $AppsArray = Get-Content $FullFilePath

    Write-Host "`n################################################################`n" -ForegroundColor Red
    Write-Host "Apps currently staged at OS level for new users:" -ForegroundColor Green

    $Counter = 0
        
    foreach ($App in $AppsArray) {
        if ($App -eq ""){
            Write-Host ""
            break
        } else {
            $Counter += 1
            Write-Host "$($Counter). $($App)" -ForegroundColor Cyan
        }
    }

    write-host "Total count of provisioned apps available are: " -NoNewline -ForegroundColor Cyan
    write-Host "<$Counter>" -ForegroundColor Yellow
}

##
# GetStagedAppXPackageList
# 
# Get the list of the staged apps available to current user.
#
# @param <String> OutputDirectoryPath The path of the output directory. 
Function GetStagedAppXPackageList {
    $FullFilePath = "$OutputDirectoryPath\Available_Apps_List.txt"
    
    $AppsArray = Get-Content $FullFilePath

    Write-Host "`n################################################################`n" -ForegroundColor Red
    Write-Host "Apps currently staged for current user <$($CurLoggedInUser)>:" -ForegroundColor Green

    $Counter = 0
        
    foreach ($App in $AppsArray) {
        if ($App -eq ""){
            Write-Host ""
            break
        } else {
            $Counter += 1
            Write-Host "$($Counter). $($App)" -ForegroundColor Cyan
        }
    }

    write-host "Total count of apps available are: " -NoNewline -ForegroundColor Cyan
    write-Host "<$Counter>" -ForegroundColor Yellow
}

##
# GetCurUserAppxPackageList
#
# Gets a list of the app packages that are installed for current user and redirects outputs
# to a local file. 
Function GetCurUserAppxPackageList {
    $FullFilePath = "$OutputDirectoryPath\Current_User_Installed_Apps_List.txt"

    OutputTextExist $FullFilePath

    try 
    {
        $CurUserInstalledAppsArray = Get-AppxPackage -User $CurLoggedInUser | Select-Object -ExpandProperty Name
    }
    catch 
    {
        Write-Host "Error: $($_.Exception.Message)"
        return    
    }

    Write-Host "`n################################################################`n" -ForegroundColor Red
    Write-Host "Apps that are currently installed under current user <$($CurLoggedInUser)>:" -ForegroundColor Green
    
    $Counter = 0;

    Foreach ($Apps in $CurUserInstalledAppsArray) {
        $Counter += 1

        Write-Host "$($Counter). $($Apps)" -ForegroundColor Cyan   

        # Append apps to a txt file in documents directory.
        Write-Output $Apps | Out-File -FilePath $FullFilePath -Append
    }

    # Display total count to text file 
    Write-Output "" | Out-File -FilePath $FullFilePath -Append
    Write-Output "Total count of apps installed under current user <$($CurLoggedInUser)>: <$($Counter)>" | Out-File -FilePath $FullFilePath -Append 
    Write-Host "`nTotal count of apps installed under current user <$($CurLoggedInUser)>: " -Foreground Cyan -NoNewline
    Write-Host "<$($Counter)>`n" -Foreground Yellow

    # Write-Host "`n################################################################`n" -ForegroundColor Red
}

##
# RemoveAppForCurUser
# 
# Removes the app for the current user. Checks to see if the removed function failed 
# by rechecking to see if app is installed.
#
# @param <string> UserPrompt The inputted value from user
# @return <boolean> True if app was removed and not found in the installed list. False otherwise.
Function RemoveAppForCurUser ($UserPrompt) {
    [array]$AppPackageArray = Get-AppxPackage -Name "*$($UserPrompt)*" | Select-Object -ExpandProperty PackageFullName 
    $GreaterThanOne = CheckForMoreThanOneApp $UserPrompt $AppPackageArray

    if ($GreaterThanOne -eq $True) {
        return $false
    }

    try
    {
        # Write-Host "     Running command: `'Get-AppxPackage -Name `"*$($UserPrompt)*`" | Remove-AppxPackage'..." -ForegroundColor Cyan
        $FoundApp = Get-AppxPackage -Name "*$($UserPrompt)*" | Select-Object -ExpandProperty PackageFullName 

        $Message = "Removing app <$($FoundApp)>..."
        AddToLog $Message

        Write-Host "     $($Message)" -ForegroundColor Cyan

        Get-AppxPackage -Name "*$($UserPrompt)*" | Remove-AppxPackage
        
        $SuccessMessage = "Successfully removed app <$($AppPackageArray[0])>"
        Write-Host "     $($SuccessMessage)`n" -ForegroundColor Green
        AddToLog $SuccessMessage

        return $true
    }
    catch
    {
        $ErrorMessage = "Error: $($_.Exception.Message)"
        Write-Host "     $($ErrorMessage)`n" -ForegroundColor Red
        AddToLog $ErrorMessage
        return $False
    }
}

##
# CheckIfAppExistAtProvision
#
# Everytime we edit the list at provision, we always edit the list locally as well.
# To prevent the many times we need to elevate, because getting the appx provision list
# requires elevation, we just basically search the local list for a match.
# 
# @param <string> AppName The name of the app to search for in Provision.
# @return <string> FoundAppsArray The array of the apps found at provision local list.
Function CheckIfAppExistAtProvision ($AppName) {
    $FullFilePath = "$($OutputDirectoryPath)\$($ProAppListName)"    
    
    [array]$AppsArray = Get-Content $FullFilePath
    $Counter = 0
    
    $FoundArray = @()

    foreach ($App in $AppsArray) {
        if ($App -Match "Total count of provisioned") {
            continue
        }

        if ($App -Match $AppName){
            $Counter += 1
            $FoundArray += $App
        }
    }

    $Counter2 = 0

    if ($FoundArray.Length -gt 0) {
        Write-Host "     Found the following match for <$($AppName)> staged at provisioned OS level:`n" -ForegroundColor Green
        AddToLog "Found app(s) that matches <$($AppName)>"        
        
        foreach ($FoundApp in $FoundArray) {
            $Counter2 += 1
            $FoundApps = "$($Counter2). $($FoundApp)"
            Write-Host "     $($FoundApps)" -ForegroundColor Yellow
            AddToLog "   $($FoundApps)"  
        }
        Write-Host ""
    } else {
        $Message = "Not found! Did not find a match for <$($AppName)> staged at provisioned level"
        Write-Host "     $Message.`n" -ForegroundColor Red
        AddToLog $Message
    }

    return $AppsArray
}

##
# CheckIfAppIsInstalledForCurUser
# 
# Checks to see if app is installed for the current logged in user.
# 
# @param <string> UserPrompt The app name inputted by the user
# @return <boolean> True or false base on found or not
Function CheckIfAppIsInstalledForCurUser ($UserPrompt) {
    try 
    {
        $AppName = Get-AppxPackage -User $CurLoggedInUser -Name "*$($UserPrompt)*"
    }
    catch
    {
        $ErrorMessage = "     Error: CheckIfAppIsInstalledForCurUser: $($_.Exception.Message)`n"
        AddToLog $ErrorMessage
        Write-Host $ErrorMessage
    }
    
    if ($AppName -ne $null) {
        return $true
    } elseif ($AppName -eq $Null) {
        return $false
    }
}

##
# GetAppFolderPath
#
# Gets the path for the appx bundle directory.
# 
# @param <string> AppName The name of the app to search for in the bundle directory.
# @return <string> "NONE" if no match. Otherwise returns the folder path to a match.
Function GetAppFolderPath ($AppName) {
    [array]$FoundFolderName = Get-ChildItem -Path $AppXBundleDir -Name -Directory | Select-String -Pattern $AppName
    
    if ($FoundFolderName.Length -gt 1) {
        Write-Host "     There are more than one app folder that matches your input of <$($AppName)>." -ForegroundColor Red
        Write-Host "     Please use the list below to help you input a more specific app to process:`n" -ForegroundColor Red

        $Counter = 0
        foreach ($App in $FoundFolderName) {
            $Counter += 1
            Write-Host "     $($Counter). $($App)" -ForegroundColor Cyan
        }

        $ErrorMessage = "Error:: GetAppFolderPath(): There were multiple matches when trying to add an app <$($AppName)>."
        AddToLog $ErrorMessage

        Write-Host ""
        return "MULTIPLE"
    }

    if (($FoundFolderName -ne "") -and ($FoundFolderName -ne $Null)) {
        $FolderPath = "$($AppXBundleDir)$($FoundFolderName)\"
        return $FolderPath
    } else {
        return "NONE"
    }
}

##
# InstallDependencies
# 
# Set location to the folder of dependencies and installs them 
# one at a time.
#
# @param <string> AppFolderPath The path to the app folder.
Function InstallDependencies ($AppDependencyPath) {
    $FilePath = "$($CurWorkingDir)\InstallDependencies.ps1"
           
    # Call the CheckAppForAllUsers script using the ampersand to tell powershell 
    # to execute the scriptblock expression. Without the ampersand, errors. Pass
    # in the app name to search for from input as an argument. 
    & $FilePath -Arg1 $UserPrompt -Arg2 $AppDependencyPath | Out-Null
}

##
# InstallApp
#
# Helper method will set location to path of appxbundle and install app. 
# If errors out add to log and return. 
# 
# @param <string> AppName The name of the app to find a match for.
# @param <string> AppFolderPath The folder path to the matched app.
Function InstallApp ($AppName, $AppFolderPath) {
    try 
    {
        [array]$AppFilePaths = Get-ChildItem -Path $AppFolderPath -Name -File | Select-String -Pattern $AppName 
    }
    catch
    {
        $ErrorMessage = "Error:: InstallAppForCurUser(): $_.Exception.Message`n" 
        AddToLog $ErrorMessage
        Write-Host "     $ErrorMessage" -ForegroundColor Red
        return                
    }

    try
    {
        Set-Location $AppFolderPath
    }
    catch
    {
        $ErrorMessage = "Error:: InstallAppForCurUser(): $_.Exception.Message`n" 
        AddToLog $ErrorMessage
        Write-Host "     $ErrorMessage" -ForegroundColor Red
        return      
    }

    foreach ($AppFilePath in $AppFilePaths) {
        if (($AppFilePath -like "*.appxbundle") -Or ($AppFilePath -like "*.msixbundle") -Or ($AppFilePath -like "*.Appx")) {
            
            $SplittedAppName = Split-Path -Path $AppFolderPath -Leaf
                            
            $InstallingMessage = "Installing app <$($SplittedAppName)>..."
            AddToLog $InstallingMessage
            Write-Host "     $($InstallingMessage)" -ForegroundColor Cyan
                            
            try 
            {
                Add-AppxPackage -Path ".\$($AppFilePath)"

                $IsInstalled = CheckIfAppIsInstalledForCurUser $AppName

                if ($IsInstalled -eq $True) {
                    $SuccessMessage = "Successfully installed the app <$($SplittedAppName)>!"
                    Write-Host "     $($SuccessMessage)`n" -ForegroundColor Green
                    AddToLog $SuccessMessage
                    return
                } else {
                    $ErrorMessage = "Error: InstallAppForCurUser(): failed to install the app <$($SplittedAppName)>!"
                    Write-Host "     $ErrorMessage`n" -ForegroundColor Red
                    AddToLog $ErrorMessage
                    return
                }

            }
            catch
            {
                $ErrorMessage = "Error:: InstallAppForCurUser(): $_.Exception.Message"  
                AddToLog $ErrorMessage
                Write-Host "     $($ErrorMessage)`n" -ForegroundColor Red 
                return    
            }
        }
    }
}

##
# InstallAppForCurUser
#
# Checks to see if we have the appx bundle at root C drive in the 
# AppXBundles folder. If exists, then installs that app for current
# logged in user.
#
# @param <string> AppName The name of the app to be installed.
Function InstallAppForCurUser ($AppName) {
    $AppFolderPath = GetAppFolderPath $AppName

    if ($AppFolderPath -eq "MULTIPLE") {
            break
    } elseif ($AppFolderPath -ne "NONE") {
        # look for dependency folder
        $AppDependencyFolderPath = "$($AppFolderPath)Dependency"

        if ((Test-Path $AppDependencyFolderPath) -eq $True) {
            write-host "     Installing dependencies...`n" -ForegroundColor Cyan
            AddToLog "Installing dependencies..."

            InstallDependencies $AppDependencyFolderPath
            InstallApp $AppName $AppFolderPath
        }
        else {
            $ErrorMessage = "Error:: InstallAppForCurUser(): a dependency folder does not exist for this app!"
            AddToLog $ErrorMessage
            Write-Host "     $($ErrorMessage)`n" -ForegroundColor Red
            Write-Host "     You must add the appx dependencies in a directory called 'Dependency' in " -ForegroundColor Red
            Write-Host "     $($AppFolderPath)`n" -ForegroundColor Red

            $UserPrompt = ""

            while (($UserPrompt -ne "Y") -Or ($UserPrompt -ne "y")) {
                Write-Host "     Try to install the app anywase (y/n)? " -NoNewline
                $UserPrompt = Read-Host

                if (($UserPrompt -eq "n") -Or ($UserPrompt -eq "N")) {
                    break
                }
            }

            write-Host ""

            if (($UserPrompt -eq "n") -Or ($UserPrompt -eq "N")) {
                return
            } else {
                InstallApp $AppName $AppFolderPath
                return
            }
        }
    } else {
            Write-Host "     Error: There is no match for <$($UserPrompt)> in the AppXBundles directory. Add the appx bundle" -ForegroundColor Red 
            Write-Host "            to `'$($AppXBundleDir)`' and re-run. App folder names in this directory must be named" -ForegroundColor Red
            Write-Host "            fully. Ex) `'$($AppXBundleDir)Calculator\`'. Hint: FIddler4 => APPX bundle link.`n" -ForegroundColor Red

            AddToLog "There were no matches for <$($AppName)> in appxbundles directory."

            return
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
# @param <array> AppsArray The array of the apps we want to check for.
# @param <string> InputAppName The app name from user input.
# @return <boolean> True if app array is greater than one. False otherwise.
Function CheckForMoreThanOneApp ($InputAppName, $AppsArray) {
    if ($AppsArray.Length -gt 1) {
        Write-Host "     There are more than one app that matches your input of <$($InputAppName)>." -ForegroundColor Red
        Write-Host "     Please use the list below to help you input a more specific app to process:`n" -ForegroundColor Red
        
        $Counter = 0

        foreach ($App in $AppPackageArray) {
            $Counter += 1
            Write-Host "     $($Counter). $($App)" -ForegroundColor Cyan
        }

        AddToLog "There were more than one match for <$($InputAppName)>."

        Write-Host ""
        return $true
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
    $LogFilePath = "$($OutputDirectoryPath)\Log.txt"
    $DateTime = Get-Date
    $MessageWithDateTime = "- $($DateTime): $($Message)"

    if (($Message -ne $NULL) -or ($Message -ne "")) {
        Write-Output $MessageWithDateTime | Out-File -FilePath $LogFilePath -Append
    }
}

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
# ProcessCommands
#
# Process the commands from user input by invoking other helper functions.
# 
# @param <string> CommandNumber The number input from the user.
Function ProcessCommands ($CommandNumber, $SkipPromptFlag, $AppNameParam) {
    switch ( $UserPrompt ) 
    {

        "0" {
            Write-Host "     Enter the full name of the app to search for (enter `'q`' to go back): " -NoNewLine
            $UserPrompt = Read-Host

            AddToLog "Option 0 selected: Checking for installed app <$($UserPrompt)>..."

            if ($UserPrompt -eq "q" -Or $UserPrompt -eq "Q") {
                $UserPrompt = ""
                AddToLog "User escaped..."
                continue
            }
                
            Write-Host " "
                
            $IsInstalled = CheckIfAppIsInstalledForCurUser $UserPrompt

            if ($IsInstalled -eq $true) {
                Write-Host "     Found! The app(s) below matched <$($UserPrompt)> and is installed for current user <$($CurLoggedInUser)>:" -ForegroundColor Green

                $Counter = 0

                $InstalledAppsArray = Get-AppxPackage -User $CurLoggedInUser -Name "*$($UserPrompt)*"
                
                foreach ($App in $InstalledAppsArray) {
                    $Counter += 1
                    Write-Host "     $($Counter). $($App)" -ForegroundColor Yellow            
                }

                Write-Host ""
            } elseif ($IsInstalled -eq $false) {
                Write-Host "     Not Found! There are currently no installed app that matched <$($UserPrompt)> for current user <$($CurLoggedInUser)>.`n" -ForegroundColor Red
            }

            break
        }
        "1" {
            # If appx bundle dir does not exist, no point continuing.
            if (!(Test-Path -Path $AppXBundleDir)) {
                Write-Host "     Error: No such directoy `'AppXBundles`' exists in the root `'C:\`' drive." -ForegroundColor Red
                Write-Host "            In order for installation to happen you must copy and paste the directory" -ForegroundColor Red
                Write-Host "            at `'Vol2\Install\Microsoft Products\AppXBundles`' to the root `'C:\`' drive." -ForegroundColor Red
                Write-Host "            Please do this first then re-run this script to install." -ForegroundColor Red

                AddToLog "Option 1 selected: Trying to install. Error: could not find AppXBundle directory."

                break
            }

            Write-Host "     Enter the full name of the app to install/re-install (enter `'q`' to go back): " -NoNewline
            $UserPrompt = Read-Host
            Write-Host " "
                 
            if ($UserPrompt -eq "q" -Or $UserPrompt -eq "Q") {
                $UserPrompt = ""
                AddToLog "User escaped..."
                continue
            }

            AddToLog "Option 1 selected: trying to install app <$($UserPrompt)>..."

            InstallAppForCurUser $UserPrompt

            break
        }
        "2" {
            Write-Host "     Enter the full name of the app you would like to uninstall (enter `'q`' to go back): " -NoNewline
            $UserPrompt = Read-Host
            Write-Host ""
                
            if ($UserPrompt -eq "q" -Or $UserPrompt -eq "Q") {
                $UserPrompt = ""
                AddToLog "User escaped..."
                continue
            }

            AddToLog "Option 2 selected: trying to uninstall app <$($UserPrompt)>..."

            $IsInstalled = CheckIfAppIsInstalledForCurUser $UserPrompt

            if ($IsInstalled -eq $true) {
                $IsRemoved = RemoveAppForCurUser $UserPrompt
            } else {
                $Message = "Not Found! There are currently no installed app that matched <$($UserPrompt)> for current user <$($CurLoggedInUser)>."
                Write-Host "     $($Message)`n" -ForegroundColor Red
                AddToLog $Message
            }

            break
        }
        "3" {
            # If appx bundle dir does not exist, no point continuing.
            if (!(Test-Path -Path $AppXBundleDir)) {
                Write-Host "     Error: No such directoy `'AppXBundles`' exists in the root `'C:\`' drive." -ForegroundColor Red
                Write-Host "            In order for installation to happen you must copy and paste the directory" -ForegroundColor Red
                Write-Host "            at `'Vol2\Install\Microsoft Products\AppXBundles`' to the root `'C:\`' drive." -ForegroundColor Red
                Write-Host "            Please do this first then re-run this script to install." -ForegroundColor Red
                break
            }

            Write-Host "     Enter the full name of the app to uninstall and reinstall (enter `'q`' to go back): " -NoNewline
            $UserPrompt = Read-Host 
            Write-Host " "

            if ($UserPrompt -eq "q" -Or $UserPrompt -eq "Q") {
                $UserPrompt = ""
                AddToLog "User escaped..."
                continue
            }

            AddToLog "Option 3 selected: attempting to remove and reinstall..."

            $IsInstalled = CheckIfAppIsInstalledForCurUser $UserPrompt

            if ($IsInstalled -eq $true) {
                $IsRemoved = RemoveAppForCurUser $UserPrompt
                            
                if ($IsRemoved -eq $true) {
                    InstallAppForCurUser $UserPrompt
                } 

                break
            } else {
                $InstallAppYN = ""

                while (($InstallAppYN -ne "n") -or ($InstallAppYN -ne "N")) {
                    $Message = "No installed app matched <$($UserPrompt)>"
                    Write-Host "     $($Message). Would you like to install this app (y/n): " -ForegroundColor Red -NoNewline
                    
                    AddToLog $Message

                    $InstallAppYN = Read-Host
                    Write-Host ""
                        
                    if (($InstallAppYN -eq "y") -or ($InstallAppYN -eq "Y")) {
                        InstallAppForCurUser $UserPrompt
                        break
                    } else {
                        continue
                    }
                }
            }
        }
        "4" {
            Write-Host "     Enter the full app name you would like to search for (enter `'q`' to go back): " -NoNewline
            $UserPrompt = Read-Host
            Write-Host ""

            if ($UserPrompt -eq "q" -Or $UserPrompt -eq "Q") {
                $UserPrompt = ""
                AddToLog "User escaped..."
                continue
            }

            AddToLog "Option 4 selected: checking to see if app exists at provision..."

            $AppExists = CheckIfAppExistAtProvision $UserPrompt
            break
        }
        "5" {
            $UserPrompt = ""

            if (($SkipPromptFlag -eq $Null) -or ($SkipPromptFlag -ne $True)) {
                Write-Host "     Enter the full app name you would like to add/stage at provisioned OS level: " -NoNewline 
                $UserPrompt = Read-Host
                Write-Host ""
            } else {
                $UserPrompt = $AppNameParam
            }

            if ($UserPrompt -eq "q" -Or $UserPrompt -eq "Q") {
                $UserPrompt = ""
                AddToLog "User escaped..."
                continue
            }

            # Check if appx bundle exist. If not no point continuing.
            $AppFolderPath = GetAppFolderPath $UserPrompt

            AddToLog "Option 5 selected: adding/staging app to provision level..."

            if ($AppFolderPath -eq "MULTIPLE") {
                break
            } elseif ($AppFolderPath -ne "NONE") {
                $AppFilePath = Get-ChildItem -Path $AppFolderPath -Name -File -Filter "*xBundle"  | Select-String -Pattern $UserPrompt

                $AppXFullPath = "$($AppFolderPath)$($AppFilePath)"

                # Get the current working directory so that we can call the correct file. 
                $CurrentWorkingDirectory = Get-Location | Select-Object -ExpandProperty Path
                $FilePath = "$CurrentWorkingDirectory\StageAppToProvision.ps1"

                # Call the StageAppToProvision script using the ampersand to tell powershell 
                # to execute the scriptblock expression. Without the ampersand, errors. Pass
                # in the app name to search for from input as an argument. 
                & $FilePath -Arg1 $UserPrompt -Arg2 $AppXFullPath | Out-Null
            } else {
                Write-Host "     Error: There is no match for <$($UserPrompt)> in the AppXBundles directory. Add the appx bundle" -ForegroundColor Red 
                Write-Host "            to `'$($AppXBundleDir)`' and re-run. App folder names in this directory must be named" -ForegroundColor Red
                Write-Host "            fully. Ex) `'$($AppXBundleDir)Calculator\`'. Hint: FIddler4 => APPX bundle link.`n" -ForegroundColor Red
                AddToLog "Error: There is no match for <$($UserPrompt)> in the AppXBundles directory"
                break
            }
                
            break
        }
        "6" {
            # TODO: AS OF 6/30/2021...Need to check elevated file script and outputs.
            Write-Host "     Enter the full app name to remove from the provisioned OS level: " -NoNewline 
            $UserPrompt = Read-Host
            Write-Host ""

            if ($UserPrompt -eq "q" -Or $UserPrompt -eq "Q") {
                $UserPrompt = ""
                AddToLog "User escaped..."
                continue
            }

            AddToLog "Option 6 selected: removing app from provisioned OS level..."

            # Get the current working directory so that we can call the correct file. 
            $CurrentWorkingDirectory = Get-Location | Select-Object -ExpandProperty Path
            $FilePath = "$CurrentWorkingDirectory\RemoveAppFromProvision.ps1"

            # Call the RemoveAppFromProvision script using the ampersand to tell powershell 
            # to execute the scriptblock expression. Without the ampersand, errors. Pass
            # in the app name to search for from input as an argument. 
            & $FilePath -Arg1 $UserPrompt | Out-Null
            break
        }
        "7" {
            Write-Host "     Enter the full app name to search for all users: " -NoNewline 
            $UserPrompt = Read-Host
            Write-Host ""

            if ($UserPrompt -eq "q" -Or $UserPrompt -eq "Q") {
                $UserPrompt = ""
                AddToLog "User escaped..."
                continue
            }

            # Get the current working directory so that we can call the correct file. 
            $CurrentWorkingDirectory = Get-Location | Select-Object -ExpandProperty Path
            $FilePath = "$CurrentWorkingDirectory\CheckAppForAllUsers.ps1"
           
            # Call the CheckAppForAllUsers script using the ampersand to tell powershell 
            # to execute the scriptblock expression. Without the ampersand, errors. Pass
            # in the app name to search for from input as an argument. 
            & $FilePath -Arg1 $UserPrompt | Out-Null
           
            # TODO GET CURRENT COUNT OF LOCAL ACCOUNTS AND DISPLAY ON SUCCESS          

            ## After elevated script exits check exit code and handle here
            if ($LASTEXITCODE -eq 0) {
                # Display the app on the list show it here. 
                $AppInfoFilePath = "$($OutputDirectoryPath)\All_Users_App_Search.txt"
                $AppsInfoArray = Get-Content $AppInfoFilePath
                
                $Counter = 0

                Write-Host "     Found! This app is installed for the following user(s):" -ForegroundColor Green
                foreach ($UserInfo in $AppsInfoArray) {
                    $Counter += 1
                    Write-Host "     $($Counter). $($UserInfo)" -ForegroundColor Yellow    
                }
                Write-Host ""
            } elseif ($LASTEXITCODE -eq 1) {
                Write-Host "     Not found! No installed app matched <$UserPrompt>.`n" -ForegroundColor Red 
            } elseif ($LASTEXITCODE -eq 2) {
                Write-Host "     Error: command failed to search the app for all current users.`n" -ForegroundColor Red
            } elseif ($LASTEXITCODE -eq 3) {
                Write-Host "     Error: command failed to redirect to output file.`n" -ForegroundColor Red
            }  
            else {
                Write-Host "     Error: wow, something is wrong in the script itself!!!`n" -ForegroundColor Red
            }
           
            break           
        }

        # TODO: check this for multiple match results. If multiple match tell the user to narrow it down. 
        # MAKE SURE YOU CHECK THE INSTALLAPPFORALLUSERS. We need to use the APP BUNDLE FOR THIS INSTEAD.
        "8" {
        
            if ($UserPrompt -eq "q" -Or $UserPrompt -eq "Q") {
                $UserPrompt = ""
                AddToLog "User escaped..."
                continue
            }
               
           # Get the current working directory so that we can call the correct file. 
           $CurrentWorkingDirectory = Get-Location | Select-Object -ExpandProperty Path
           $FilePath = "$CurrentWorkingDirectory\InstallAppForAllUsers.ps1"
           
           # Call the RemoveAppForAllUsers script using the ampersand to tell powershell 
           # to execute the scriptblock expression. Without the ampersand, errors. Pass
           # in the app name to search for from input as an argument. 
           & $FilePath -Arg1 $AppNameParam | Out-Null
           
           ## After elevated script exits check exit code and handle here
           if ($LASTEXITCODE -eq 0) {
               Write-Host "     Successfully Install/Reinstall the app for all current users.`n" -ForegroundColor Green
           } elseif ($LASTEXITCODE -eq 1) {
               Write-Host "     Error: command failed to install/reinstall the app for all current users.`n" -ForegroundColor Red 
           } elseif ($LASTEXITCODE -eq 2) {
               Write-Host "     Error: command failed to update the local list of all installed apps for current user.`n" -ForegroundColor Red
           } elseif ($LASTEXITCODE -eq 3) {
               Write-Host "     Error: elevated script failed to do anything.`n" -ForegroundColor Red                
           } 
           else {
               Write-Host "     Error: wow, something is wrong in the script itself!!!`n" -ForegroundColor Red
           }
           
           break
        }
        # TODO: check this for multiple match results. If multiple match tell the user to narrow it down. 
        "9" {
            Write-Host "     Enter the full app name to uninstall for all users of this workstation: " -NoNewline 
            $UserPrompt = Read-Host
            Write-Host ""

            if ($UserPrompt -eq "q" -Or $UserPrompt -eq "Q") {
                $UserPrompt = ""
                AddToLog "User escaped..."
                continue
            }

            # Get the current working directory so that we can call the correct file. 
            $CurrentWorkingDirectory = Get-Location | Select-Object -ExpandProperty Path
            $FilePath = "$CurrentWorkingDirectory\RemoveAppForAllUsers.ps1"

            # Call the RemoveAppForAllUsers script using the ampersand to tell powershell 
            # to execute the scriptblock expression. Without the ampersand, errors. Pass
            # in the app name to search for from input as an argument. 
            & $FilePath -Arg1 $UserPrompt | Out-Null

            # After elevated script exits check exit code and handle here
            if ($LASTEXITCODE -eq 0) {
                Write-Host "     Successfully installed the app for all current users.`n" -ForegroundColor Green
            } elseif ($LASTEXITCODE -eq 1) {
                Write-Host "     Error: command failed to install the app for all current users.`n" -ForegroundColor Red 
            } elseif ($LASTEXITCODE -eq 2) {
                Write-Host "     Error: command failed to update the local list of all installed apps for current user.`n" -ForegroundColor Red
            } elseif ($LASTEXITCODE -eq 3) {
                Write-Host "     Error: elevated script failed to do anything.`n" -ForegroundColor Red                
            } 
            else {
                Write-Host "     Error: wow, something is wrong in the script itself!!!`n" -ForegroundColor Red
            }

            break
        }
        "test" {
            Write-Host "testing"
            # Get the current working directory so that we can call the correct file. 
            $CurrentWorkingDirectory = Get-Location | Select-Object -ExpandProperty Path
            $FilePath = "$CurrentWorkingDirectory\test.ps1"

            # Call the RemoveAppForAllUsers script using the ampersand to tell powershell 
            # to execute the scriptblock expression. Without the ampersand, errors. Pass
            # in the app name to search for from input as an argument. 
            & $FilePath -Arg1 $UserPrompt $result
             
            $resultval = Get-Variable -Name "result" 

            Write-Host $resultval.value

        }
        default { break } 
    }

    return
}

##
# StartPrompt
#
# Main working method for prompting the user what to do. 
# Pretty self explanatory. Please read. Sorry.
Function StartPrompt {
    $UserPrompt = "-1"

    while (($UserPrompt -ne "q") -or ($UserPrompt -ne "Q")) {
        Write-Host "################################################################`n" -ForegroundColor Red
        
        Write-Host "What would you like for me do today (enter a number)?`n"
        Write-Host "Options:"
        Write-Host "     (0) - " -NoNewLine
        Write-Host "Check" -NoNewline -ForegroundColor Yellow
        Write-Host " if an app" -NoNewline
        Write-Host " is installed" -NoNewline -ForegroundColor Yellow
        Write-Host " for the " -NoNewLine
        Write-Host "current user." -ForegroundColor Yellow
        Write-Host "     (1) - " -NoNewLine 
        Write-Host "Install/Reinstall" -NoNewline -ForegroundColor Yellow
        Write-Host " an app for the " -NoNewLine
        Write-Host "current user." -ForegroundColor Yellow 
        Write-Host "     (2) -" -NoNewline
        Write-Host " Uninstall" -ForegroundColor Yellow -NoNewline
        Write-Host " an app for the " -NoNewLine 
        Write-Host "current user." -ForegroundColor Yellow
        Write-Host "     (3) - " -NoNewLine
        Write-Host "Uninstall and Reinstall" -ForegroundColor Yellow -NoNewline
        Write-Host " an app for the current user " -NoNewLine
        Write-Host "<$($CurLoggedInUser)>." -ForegroundColor Yellow
        Write-Host "     ***** Danger Zone: below commands affects all new users *****" -ForegroundColor Red
        Write-Host "     (4) - " -NoNewline
        Write-Host "Check" -NoNewline -ForegroundColor Yellow
        Write-Host " if an app is" -NoNewline
        Write-Host " staged" -NoNewline -ForegroundColor Yellow
        Write-Host " at the " -NoNewLine 
        Write-Host "provisioned OS level" -NoNewline -ForegroundColor Yellow
        Write-Host " for " -NoNewLine 
        Write-Host "new users." -ForegroundColor Yellow 
        Write-Host "     (5) - " -NoNewline
        Write-Host "Add/Stage " -NoNewline -ForegroundColor Yellow
        Write-Host "an app to the " -NoNewline
        Write-Host "provisioned OS level." -ForegroundColor Yellow
        Write-Host "     (6) - " -NoNewline
        Write-Host "Uninstall" -NoNewline -ForegroundColor Yellow 
        Write-Host " an app " -NoNewLine 
        Write-Host "staged " -NoNewLine -ForegroundColor Yellow
        Write-Host "at the " -NoNewline
        Write-Host "provisioned OS level" -NoNewline -ForegroundColor Yellow
        Write-Host " for " -NoNewLine 
        Write-Host "new users." -ForegroundColor Yellow
        Write-Host "     ***** Danger Zone: below commands affects all existing users *****" -ForegroundColor Red
        Write-Host "     (7) - " -NoNewline
        Write-Host "Check" -NoNewline -ForegroundColor Yellow
        Write-Host " if an app" -NoNewline
        Write-Host " is installed" -NoNewline -ForegroundColor Yellow
        Write-Host " for " -NoNewLine
        Write-Host "other existing users." -ForegroundColor Yellow
        Write-Host "     (8) - " -NoNewLine
        Write-Host "Install" -NoNewline -ForegroundColor Yellow
        Write-Host " an app for " -NoNewLine
        Write-Host "all current users" -NoNewline -ForegroundColor Yellow
        Write-Host " of this workstation " -NoNewLine
        Write-Host "<$($env:COMPUTERNAME)>." -ForegroundColor Yellow
        Write-Host "     (9) - " -NoNewLine
        Write-Host "Uninstall" -NoNewline -ForegroundColor Yellow
        Write-Host " an app for " -NoNewLine
        Write-Host "all current users" -NoNewline -ForegroundColor Yellow
        Write-Host " of this workstation " -NoNewLine
        Write-Host "<$($env:COMPUTERNAME)>." -ForegroundColor Yellow
        Write-Host "     (q) - Enter q to exit." 

        Write-Host ""
        $UserPrompt = Read-Host -Prompt "     "
        Write-Host ""
        
        # TODO: instead of doing this we can fix the ProcessCommands 
        # function to be run as a recursive function and recurse whatever
        # commands we need to do as a workflow.
        if (($UserPrompt -ne "q") -Or ($UserPrompt -ne "Q")){
            if ($UserPrompt -eq "8") {
                $UserPrompt = "5"
                
                Write-Host "     Enter the full app name to install/reinstall for all users of this workstation: " -NoNewline 
                $AppNameParam = Read-Host
                Write-Host ""

                ProcessCommands $UserPrompt $True $AppNameParam

                $UserPrompt = "8"
                ProcessCommands $UserPrompt $False $AppNameParam
                continue
            } else {
                ProcessCommands $UserPrompt
                continue            
            }
        }
    }
}


######################### MAIN ##########################################################

# Checks and sets up the output directory
AppTestOUtputDirExist

# Append the apps info to the output directory
# by starting a new process in elevated mode
GetAppsInfo

# Check if log file exist, if it does remove it.
# We want a fresh log of every new instance only.
$LogFilePath = "$($OutputDirectoryPath)\Log.txt"

Write-Host $LogFilePath

OutputTextExist $LogFilePath

# Get installed apps for current user and output to text file. 
GetCurUserAppxPackageList

# Interactive menu
StartPrompt

Write-Host "Current execution policy for this script: " -NoNewline

Write-Host "$(Get-ExecutionPolicy)." -fore Yellow
Write-Host ""

Write-Host "Please remember to delete `'GetWinAppsInfoAndTroubleshoot`' directory off this workstation when you are finished.`n" -ForegroundColor Red

# User has quit, ask if output directory should be 
# deleted from the current user's desktop.
# It should be the case that we always delete it after 
# we are done troubleshooting, but what if?

$RemoveWAF = "n"

While (($RemoveWAF -ne "Y") -or ($RemoveWAF -ne "y")) {
    Write-Host "Would you like to remove the WindowsAppInfo folder `nthat I created on the Desktop before leaving (y/n): " -NoNewline
    $RemoveWAF = Read-Host

    if (($RemoveWAF -eq "y") -or ($RemoveWAF -eq "Y")) {
        Remove-Item $OutputDirectoryPath -Recurse
    } elseif (($RemoveWAF -eq "n") -or ($RemoveWAF -eq "N")) {
        break
    } else {
        write-host ""
        continue
    }
}

