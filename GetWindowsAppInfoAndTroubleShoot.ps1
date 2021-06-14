﻿###
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
# 6/11/2021
##

######################### GLOABL VARIABLES ############################
$CurLoggedInUser = Get-WmiObject -class Win32_ComputerSystem | Select-Object -ExpandProperty Username
$AppXBundleDir = 'C:\AppXBundles\'
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
        }
        catch
        {
            Write-Host "`nError: failed to create <$($OutputDirectoryPath)> : $($_.Exeption.Message)"
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
        Remove-Item -Path $FullPath
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
# CheckIfAppIsInstalledForCurUser
# 
# Checks to see if app is installed for the current logged in user.
# 
# @param <string> UserPrompt The app name inputted by the user
# @return <boolean> True or false base on found or not
Function CheckIfAppIsInstalledForCurUser ($UserPrompt) {
    $AppName = Get-AppxPackage -User $CurLoggedInUser -Name "*$($UserPrompt)*"
    
    if ($AppName -ne $null) {
        return $true
    } elseif ($AppName -eq $Null) {
        return $false
    }
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
    $AppPackageName = Get-AppxPackage -Name "*$($UserPrompt)*" | Select-Object -ExpandProperty PackageFullName 
    
    try
    {
        # Write-Host "     Running command: `'Get-AppxPackage -Name `"*$($UserPrompt)*`" | Remove-AppxPackage'..." -ForegroundColor Cyan
        Get-AppxPackage -Name "*$($UserPrompt)*" | Remove-AppxPackage
        
        Write-Host "     Successfully removed app for <$($AppPackageName)>`n" -ForegroundColor Green
        return $true
    }
    catch
    {
        Write-Host "     Error: $($_.Exception.Message)`n" -ForegroundColor Red
        return $false
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
    
    $AppsArray = Get-Content $FullFilePath
    $FoundFlag = $False
    $FoundAppsArray = @()
    $Counter = 0

    foreach ($App in $AppsArray) {
        if ($App -Match $AppName){
            Write-Host "     Found a match for <$($AppName)> staged at provisioned OS level: $($App)`n" -ForegroundColor Green
            $FoundFlag = $True
            $Counter += 1
            $FoundAppsArray += $App
        }
    }

    if ($FoundFlag -eq $False) {
        Write-Host "     Not found! No matches were found for <$($AppName)> at the provisioned OS level.`n" -ForegroundColor Red
        return "NONE"
    } else {
        return $FoundAppsArray
    }
}

Function InstallAppForCurUser ($AppName) {
    $IsInstalled = CheckIfAppIsInstalledForCurUser $AppName

    if ($IsInstalled -eq $False) {
        $AppFolderPath = GetAppFolderPath $AppName

        if ($AppFolderPath -ne "NONE") {
            $AppFilePath = Get-ChildItem -Path $AppFolderPath -Name -File | Select-String -Pattern $AppName

            $FullFilePath = "$($AppFolderPath)$($AppFilePath)"

            try 
            {
                # Write-Host "     Running command: `'Add-AppXPackage -Path $($FullFilePath)`'..." -ForegroundColor Cyan
                Add-AppxPackage -Path $FullFilePath

                $AppName = Get-AppxPackage -Name "*$($UserPrompt)*" | Select-Object -ExpandProperty PackageFullName
                Write-Host "     Successfully installed the app: <$AppName>`n" -Foreground Green
                return
            }
            catch
            {
                Write-Host "     Error: $($_.Exception.Message)." -ForegroundColor Red
                return
            }
        } else {
                Write-Host "     Error: There is no match for <$($UserPrompt)> in the AppXBundles directory. Add the appx bundle" -ForegroundColor Red 
                Write-Host "            to `'$($AppXBundleDir)`' and re-run. App folder names in this directory must be named" -ForegroundColor Red
                Write-Host "            fully. Ex) `'$($AppXBundleDir)Calculator\`'. Hint: FIddler4 => APPX bundle link." -ForegroundColor Red
                return
        }
    } else {
        # Write-Host "     App is already installed. Reinstalling using command:" -ForegroundColor Cyan
        # Write-Host "     `'Get-AppxPackage -Name `"*$($AppName)*`" | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register `"$($_.InstallLocation)\AppXManifest.xml`"}`"`'" -ForegroundColor Cyan

        try
        {
            # Try to install thru traditional way
            Get-AppxPackage -Name "*$($AppName)*" | Foreach {Add-AppxPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"}

            $AppName = Get-AppxPackage -Name "*$($UserPrompt)*" | Select-Object -ExpandProperty PackageFullName
            Write-Host "     Successfully reinstalled the app: <$AppName>`n" -Foreground Green
            return
        }
        catch 
        {
            Write-Host "     Error: $($_.Exception.Message)" -ForegroundColor Red
            return
        }

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
    $FoundFolderName = Get-ChildItem -Path $AppXBundleDir -Name -Directory |  Select-String -Pattern $AppName
    
    if (($FoundFolderName -ne "") -and ($FoundFolderName -ne $Null)) {
        $FolderPath = "$($AppXBundleDir)$($FoundFolderName)\"
        return $FolderPath
    } else {
        return "NONE"
    }
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
        Write-Host "     (1) - " -NoNewLine
        Write-Host "Check" -NoNewline -ForegroundColor Yellow
        Write-Host " if an app" -NoNewline
        Write-Host " is installed" -NoNewline -ForegroundColor Yellow
        Write-Host " for the " -NoNewLine
        Write-Host "current user." -ForegroundColor Yellow
        Write-Host "     (2) - " -NoNewLine 
        Write-Host "Install/Reinstall" -NoNewline -ForegroundColor Yellow
        Write-Host " an app for the " -NoNewLine
        Write-Host "current user." -ForegroundColor Yellow 
        Write-Host "     (3) -" -NoNewline
        Write-Host " Uninstall" -ForegroundColor Yellow -NoNewline
        Write-Host " an app for the " -NoNewLine 
        Write-Host "current user." -ForegroundColor Yellow
        Write-Host "     (4) - " -NoNewLine
        Write-Host "Uninstall and Reinstall" -ForegroundColor Yellow -NoNewline
        Write-Host " an app for the current user " -NoNewLine
        Write-Host "<$($CurLoggedInUser)>." -ForegroundColor Yellow
        Write-Host "     (5) - " -NoNewline
        Write-Host "Check" -NoNewline -ForegroundColor Yellow
        Write-Host " if an app is" -NoNewline
        Write-Host " staged" -NoNewline -ForegroundColor Yellow
        Write-Host " at the " -NoNewLine 
        Write-Host "provisioned OS level" -NoNewline -ForegroundColor Yellow
        Write-Host " for " -NoNewLine 
        Write-Host "new users." -ForegroundColor Yellow 
        Write-Host "     (6) - " -NoNewline
        Write-Host "Add/Stage " -NoNewline -ForegroundColor Yellow
        Write-Host "an app to the " -NoNewline
        Write-Host "provisioned OS level." -ForegroundColor Yellow
        Write-Host "           Danger Zone: affects all new users of this workstation." -ForegroundColor Red
        Write-Host "     (7) - " -NoNewline
        Write-Host "Uninstall" -NoNewline -ForegroundColor Yellow 
        Write-Host " an app " -NoNewLine 
        Write-Host "staged " -NoNewLine -ForegroundColor Yellow
        Write-Host "at the " -NoNewline
        Write-Host "provisioned OS level" -NoNewline -ForegroundColor Yellow
        Write-Host " for " -NoNewLine 
        Write-Host "new users." -ForegroundColor Yellow
        Write-Host "           Danger Zone: affects all new users of this workstation." -ForegroundColor Red
        Write-Host "     (8) - " -NoNewLine
        Write-Host "Uninstall" -NoNewline -ForegroundColor Yellow
        Write-Host " an app for " -NoNewLine
        Write-Host "all current users" -NoNewline -ForegroundColor Yellow
        Write-Host " of this workstation " -NoNewLine
        Write-Host "<$($env:COMPUTERNAME)>." -ForegroundColor Yellow
        Write-Host "           Danger Zone: affects all current users of this workstation." -ForegroundColor Red 
        Write-Host "     (9) - Exit." 

        Write-Host ""
        $UserPrompt = Read-Host -Prompt "     "
        Write-Host ""

        switch ( $UserPrompt ) 
        {
            "1" {
                Write-Host "     Enter the full name of the app to search for (enter `'q`' to go back): " -NoNewLine
                $UserPrompt = Read-Host

                if ($UserPrompt -eq "q" -Or $UserPrompt -eq "Q") {
                    $UserPrompt = ""
                    continue
                }
                
                Write-Host " "
                # Write-Host "     Running command: `'Get-AppxPackage -User $CurLoggedInUser -Name `"*$($UserPrompt)*`"`'...`n" -ForegroundColor Cyan
                
                $IsInstalled = CheckIfAppIsInstalledForCurUser $UserPrompt

                if ($IsInstalled -eq $true) {
                    Write-Host "     Found! The app below matched <$($UserPrompt)> and is installed for current user <$($CurLoggedInUser)>:" -ForegroundColor Green

                    $RetVal = Get-AppxPackage -User $CurLoggedInUser -Name "*$($UserPrompt)*"
                    Write-Host "     $($RetVal)`n" -ForegroundColor Yellow
                } elseif ($IsInstalled -eq $false) {
                    Write-Host "     Not Found! There are currently no installed app that matched <$($UserPrompt)> for current user <$($CurLoggedInUser)>.`n" -ForegroundColor Red
                }

                break
            }
            "2" {
                # If appx bundle dir does not exist, no point continuing.
                if (!(Test-Path -Path $AppXBundleDir)) {
                    Write-Host "     Error: No such directoy `'AppXBundles`' exists in the root `'C:\`' drive." -ForegroundColor Red
                    Write-Host "            In order for installation to happen you must copy and paste the directory" -ForegroundColor Red
                    Write-Host "            at `'Vol2\Install\Microsoft Products\AppXBundles`' to the root `'C:\`' drive." -ForegroundColor Red
                    Write-Host "            Please do this first then re-run this script to install." -ForegroundColor Red
                    break
                }

                Write-Host "     Enter the full name of the app to install/re-install (enter `'q`' to go back): " -NoNewline
                $UserPrompt = Read-Host
                Write-Host " "
                 
                if ($UserPrompt -eq "q" -Or $UserPrompt -eq "Q") {
                   $UserPrompt = ""
                   continue
                }
                
                InstallAppForCurUser $UserPrompt

                break
            }
            "3" {
                Write-Host "     Enter the full name of the app you would like to uninstall (enter `'q`' to go back): " -NoNewline
                $UserPrompt = Read-Host
                Write-Host ""
                
                if ($UserPrompt -eq "q" -Or $UserPrompt -eq "Q") {
                    $UserPrompt = ""
                    continue
                }

                $IsInstalled = CheckIfAppIsInstalledForCurUser $UserPrompt

                if ($IsInstalled -eq $true) {
                    $IsRemoved = RemoveAppForCurUser $UserPrompt
                } else {
                    Write-Host "     Not Found! There are currently no installed app that matched <$($UserPrompt)> for current user <$($CurLoggedInUser)>.`n" -ForegroundColor Red
                }

                break
            }
            "4" {
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
                    continue
                }

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
                        Write-Host "     No installed app matched <$($UserPrompt)>. Would you like to install this app (y/n): " -ForegroundColor Red -NoNewline
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
            "5" {
                Write-Host "     Enter the full app name you would like to search for (enter `'q`' to go back): " -NoNewline
                $UserPrompt = Read-Host
                Write-Host ""

                if ($UserPrompt -eq "q" -Or $UserPrompt -eq "Q") {
                    $UserPrompt = ""
                    continue
                }

                $AppExists = CheckIfAppExistAtProvision $UserPrompt
                break
            }
            "6" {
                Write-Host "     Enter the full app name you would like to add/stage at provisioned OS level: " -NoNewline 
                $UserPrompt = Read-Host
                Write-Host ""

                if ($UserPrompt -eq "q" -Or $UserPrompt -eq "Q") {
                    $UserPrompt = ""
                    continue
                }

                # Check if appx bundle exist. If not no point continuing.
                $AppFolderPath = GetAppFolderPath $UserPrompt

                if ($AppFolderPath -ne "NONE") {
                    $AppFilePath = Get-ChildItem -Path $AppFolderPath -Name -File | Select-String -Pattern $UserPrompt

                    $AppXFullPath = "$($AppFolderPath)$($AppFilePath)"

                    # Get the current working directory so that we can call the correct file. 
                    $CurrentWorkingDirectory = Get-Location | Select-Object -ExpandProperty Path
                    $FilePath = "$CurrentWorkingDirectory\StageAppToProvision.ps1"

                    # Call the StageAppToProvision script using the ampersand to tell powershell 
                    # to execute the scriptblock expression. Without the ampersand, errors. Pass
                    # in the app name to search for from input as an argument. 
                    & $FilePath -Arg1 $UserPrompt -Arg2 $AppXFullPath | Out-Null

                    # After elevated script exits check exit code and handle here
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "     Successfully added the app to the provisioned OS level for new users.`n" -ForegroundColor Green
                    } elseif ($LASTEXITCODE -eq 1) {
                        Write-Host "     Error: command failed to add app to provisioned OS level.`n" -ForegroundColor Red 
                    } elseif ($LASTEXITCODE -eq 2) {
                        Write-Host "     Error: success at add/stage to provisioned OS level but failed to update local list.`n" -ForegroundColor Red
                    } elseif ($LASTEXITCODE -eq 3) {
                        Write-Host "     Error: elevated script failed to do anything.`n" -ForegroundColor Red
                    } else {
                        Write-Host "     Error: wow, you have not accounted for this error in the script dude!!!" -ForegroundColor Red
                    }
                } else {
                        Write-Host "     Error: There is no match for <$($UserPrompt)> in the AppXBundles directory. Add the appx bundle" -ForegroundColor Red 
                        Write-Host "            to `'$($AppXBundleDir)`' and re-run. App folder names in this directory must be named" -ForegroundColor Red
                        Write-Host "            fully. Ex) `'$($AppXBundleDir)Calculator\`'. Hint: FIddler4 => APPX bundle link." -ForegroundColor Red
                        break
                }
                
                break
            }
            "7" {
                Write-Host "     Enter the full app name to remove from the provisioned OS level: " -NoNewline 
                $UserPrompt = Read-Host
                Write-Host ""

                if ($UserPrompt -eq "q" -Or $UserPrompt -eq "Q") {
                    $UserPrompt = ""
                    continue
                }

                # Get the current working directory so that we can call the correct file. 
                $CurrentWorkingDirectory = Get-Location | Select-Object -ExpandProperty Path
                $FilePath = "$CurrentWorkingDirectory\RemoveAppFromProvision.ps1"

                # Call the StageAppToProvision script using the ampersand to tell powershell 
                # to execute the scriptblock expression. Without the ampersand, errors. Pass
                # in the app name to search for from input as an argument. 
                & $FilePath -Arg1 $UserPrompt | Out-Null

                # After elevated script exits check exit code and handle here
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "     Successfully deleted the app from the provisioned OS level for new users.`n" -ForegroundColor Green
                } elseif ($LASTEXITCODE -eq 1) {
                    Write-Host "     Error: command failed to package name for <$($UserPrompt)>.`n" -ForegroundColor Red 
                } elseif ($LASTEXITCODE -eq 2) {
                    Write-Host "     Error: command failed to remove package from provisioned OS level.`n" -ForegroundColor Red
                } elseif ($LASTEXITCODE -eq 3) {
                    Write-Host "     Error: elevated script failed to do anything.`n" -ForegroundColor Red                
                } elseif ($LASTEXITCODE -eq 4) {
                    Write-Host "     Error: elevated script failed to do anything.`n" -ForegroundColor Red
                } elseif ($LASTEXITCODE -eq 5) {
                    Write-Host "     Not found! No apps matched <$($UserPrompt)> in the provisioned apps list.`n" -ForegroundColor Red
                }else {
                    Write-Host "     Error: wow, you have not accounted for this error in the script dude!!!" -ForegroundColor Red
                }

                break
            }
            "8" {
                $UserPrompt = "q"
                break
            }
            "9" {
                $UserPrompt = "q"
                break
            }
            default { break } 

        }
        
    }
}


######################### MAIN ##########################################################

# Checks and sets up the output directory
AppTestOUtputDirExist

# Append the apps info to the output directory
# by starting a new process in elevated mode
GetAppsInfo

# Get installed apps for current user and output to text file. 
GetCurUserAppxPackageList

# Interactive menu
StartPrompt

Write-Host "Current execution policy for this script: " -NoNewline

Write-Host "$(Get-ExecutionPolicy)." -fore Yellow
Write-Host ""

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

