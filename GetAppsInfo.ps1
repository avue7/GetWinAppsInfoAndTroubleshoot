###
# GetAppsInfo.ps1
#
# @Description:
# As I have not found a better way to run the main script in elevated mode, 
# while in a normal user context, this was the only way I found. This is a 
# helper script that is called from the main script GetWindowsAppInfoAndTroubleshoot.ps1.
# It invokes the following functions to grab the list for provisioned apps and apps 
# that are available to current user.
# 
# @author:
# Athit Vue
# 
# @date created:
# 6/10/2021
#
# @last updated:
# 6/11/2021
##

################ FUNCTION DEFINITION #########################

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
# GetAppXProvisionPackageList 
#
# Gets provisioned app packages staged at OS level and outputs 
# name to a text in the documents directory. 
# 
# @Param <string> OutputDirectoryPath The path of the output directory. 
Function GetAppxProvisionPackageList ($OutputDirectoryPath) {
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

## 
# GetStagedAppXPackageList 
#
# Gets apps staged and available for current user
# 
# @Param <string> OutputDirectoryPath The path of the output directory. 
Function GetStagedAppXPackageList ($OutputDirectoryPath) {
    $CurLogInUserWindowsAppsInfoPath = GetCurUserWindowsAppInfoPath
    $FullFilePath = "$CurLogInUserWindowsAppsInfoPath\Available_Apps_List.txt"

    OutputTextExist $FullFilePath

    $AppsArray = $null

    try 
    {
        $AppsArray = Get-AppxPackage -AllUsers | Where-Object {$_.PackageUserInformation -like "*staged*"} | Select-Object -ExpandProperty Name
    } 
    catch 
    {
        return $false
    }

    $Counter = 0

    foreach ($Apps in $AppsArray) {
        $Counter += 1  
        # Append app name to text file
        Write-Output $Apps | Out-File -FilePath $FullFilePath -Append
    }
    
    # Display total count to text file 
    Write-Output "" | Out-File -FilePath $FullFilePath -Append
    Write-Output "Total count of apps installed under other users than  <$($CurLoggedInUser)>: <$($Counter)>`n" | Out-File -FilePath $FullFilePath -Append 
    
    Write-Host "Done GetStagedAppXPackageList`n"

    return $true
}

#################### MAIN ############################

$OutputDirectoryPath = "$env:USERPROFILE\Desktop\WindowsAppsInfo"

$ErrorCounter = 0

# Get Provisioned (STAGED) apps in the OS level and output to text file. 
$Success1 = GetAppxProvisionPackageList $OutputDirectoryPath

# Get staged apps available for current user 
$Success2 = GetStagedAppXPackageList $OutputDirectoryPath

if (!($Success1) -and !($Success2)) {
    exit 3
} elseif (!($Success2)) {
    exit 2
} elseif (!($Success1)) {
    exit 1
}

# Uncomment below block for debugging 

#$QuitResponse = ""
#while($QuitResponse-ne "q") {
#   Write-Host "quit or not: " -NoNewline
#   $QuitResponse = Read-Host
#}
