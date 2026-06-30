# Lab 01 - JML Lifecycle Automation
# Real Microsoft Entra ID automation using Microsoft Graph PowerShell

$CsvPath = ".\jml-actions.csv"
$LogPath = ".\logs\jml-lifecycle.log"
$ReportPath = ".\reports\jml-lifecycle-report.csv"

$Results = @()

function Write-Log {
    param ([string]$Message)

    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$Timestamp - $Message" | Out-File -FilePath $LogPath -Append
}

function Write-Status {
    param (
        [string]$Message,
        [string]$Type = "Info"
    )

    switch ($Type) {
        "Success" { Write-Host "[SUCCESS] $Message" -ForegroundColor Green }
        "Warning" { Write-Host "[WARNING] $Message" -ForegroundColor Yellow }
        "Error"   { Write-Host "[ERROR] $Message" -ForegroundColor Red }
        default   { Write-Host "[INFO] $Message" -ForegroundColor Cyan }
    }
}

function Connect-Graph {
    $Context = Get-MgContext

    if (!$Context) {
        Write-Status "Connecting to Microsoft Graph..." "Warning"

        Connect-MgGraph -UseDeviceCode -Scopes `
            "User.ReadWrite.All", `
            "Group.ReadWrite.All", `
            "Directory.ReadWrite.All"
    }
    else {
        Write-Status "Already connected to Microsoft Graph." "Success"
    }
}

function Add-UserToTargetGroups {
    param (
        [string]$UserId,
        [string]$DisplayName,
        [string]$TargetGroups
    )

    if ($TargetGroups -eq "None") {
        Write-Status "No target groups assigned for $DisplayName." "Warning"
        return
    }

    $Groups = $TargetGroups -split ";"

    foreach ($GroupName in $Groups) {
        $Group = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction SilentlyContinue

        if (!$Group) {
            Write-Status "Group not found: $GroupName" "Warning"
            Write-Log "Group not found: $GroupName"
            continue
        }

        try {
            New-MgGroupMemberByRef `
                -GroupId $Group.Id `
                -BodyParameter @{
                    "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
                } `
                -ErrorAction Stop

            Write-Status "Added $DisplayName to $GroupName" "Success"
            Write-Log "Added $DisplayName to $GroupName"
        }
        catch {
            Write-Status "$DisplayName may already be a member of $GroupName." "Warning"
            Write-Log "$DisplayName may already be a member of $GroupName. Error: $($_.Exception.Message)"
        }
    }
}

function Create-Joiner {
    param ($Action)

    Write-Host ""
    Write-Status "Processing Joiner: $($Action.DisplayName)" "Info"
    Write-Log "Processing Joiner: $($Action.DisplayName)"

    $ExistingUser = Get-MgUser -Filter "userPrincipalName eq '$($Action.UserPrincipalName)'" -ErrorAction SilentlyContinue

    if ($ExistingUser) {
        Write-Status "User already exists: $($Action.UserPrincipalName)" "Warning"
        Write-Log "User already exists: $($Action.UserPrincipalName)"

        Add-UserToTargetGroups `
            -UserId $ExistingUser.Id `
            -DisplayName $Action.DisplayName `
            -TargetGroups $Action.TargetGroups

        $script:Results += [PSCustomObject]@{
            DisplayName       = $Action.DisplayName
            UserPrincipalName = $Action.UserPrincipalName
            ActionType        = "Joiner"
            ActionTaken       = "User already existed; group assignment checked"
            Status            = "Completed with warning"
        }

        return
    }

    $PasswordProfile = @{
        Password = "TempP@ssword12345!"
        ForceChangePasswordNextSignIn = $true
    }

    try {
        $NewUser = New-MgUser `
            -AccountEnabled `
            -DisplayName $Action.DisplayName `
            -MailNickname ($Action.UserPrincipalName.Split("@")[0]) `
            -UserPrincipalName $Action.UserPrincipalName `
            -Department $Action.Department `
            -JobTitle $Action.JobTitle `
            -PasswordProfile $PasswordProfile `
            -ErrorAction Stop

        Write-Status "Created user: $($Action.DisplayName)" "Success"
        Write-Log "Created user: $($Action.DisplayName)"

        Add-UserToTargetGroups `
            -UserId $NewUser.Id `
            -DisplayName $Action.DisplayName `
            -TargetGroups $Action.TargetGroups

        $script:Results += [PSCustomObject]@{
            DisplayName       = $Action.DisplayName
            UserPrincipalName = $Action.UserPrincipalName
            ActionType        = "Joiner"
            ActionTaken       = "Created user and assigned target groups"
            Status            = "Completed"
        }
    }
    catch {
        Write-Status "Failed to create joiner $($Action.DisplayName): $($_.Exception.Message)" "Error"
        Write-Log "Failed to create joiner $($Action.DisplayName): $($_.Exception.Message)"

        $script:Results += [PSCustomObject]@{
            DisplayName       = $Action.DisplayName
            UserPrincipalName = $Action.UserPrincipalName
            ActionType        = "Joiner"
            ActionTaken       = "Create user failed"
            Status            = $_.Exception.Message
        }
    }
}

function Process-Mover {
    param ($Action)

    Write-Host ""
    Write-Status "Processing Mover: $($Action.DisplayName)" "Info"
    Write-Log "Processing Mover: $($Action.DisplayName)"

    $User = Get-MgUser -Filter "userPrincipalName eq '$($Action.UserPrincipalName)'" -ErrorAction SilentlyContinue

    if (!$User) {
        Write-Status "Mover user not found: $($Action.UserPrincipalName)" "Error"
        Write-Log "Mover user not found: $($Action.UserPrincipalName)"

        $script:Results += [PSCustomObject]@{
            DisplayName       = $Action.DisplayName
            UserPrincipalName = $Action.UserPrincipalName
            ActionType        = "Mover"
            ActionTaken       = "User lookup failed"
            Status            = "User not found"
        }

        return
    }

    try {
        Update-MgUser `
            -UserId $User.Id `
            -Department $Action.Department `
            -JobTitle $Action.JobTitle `
            -ErrorAction Stop

        Write-Status "Updated department/job title for $($Action.DisplayName)" "Success"
        Write-Log "Updated department/job title for $($Action.DisplayName)"

        Add-UserToTargetGroups `
            -UserId $User.Id `
            -DisplayName $Action.DisplayName `
            -TargetGroups $Action.TargetGroups

            $TargetGroupNames = $Action.TargetGroups -split ";"

$CurrentGroups = Get-MgUserMemberOf -UserId $User.Id

foreach ($GroupObject in $CurrentGroups) {
    if ($GroupObject.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.group") {

        $GroupDetails = Get-MgGroup -GroupId $GroupObject.Id

        if ($GroupDetails.DisplayName -notin $TargetGroupNames) {
            Remove-MgGroupMemberByRef `
                -GroupId $GroupDetails.Id `
                -DirectoryObjectId $User.Id `
                -ErrorAction Stop

            Write-Status "Removed $($Action.DisplayName) from old group: $($GroupDetails.DisplayName)" "Success"
            Write-Log "Removed $($Action.DisplayName) from old group: $($GroupDetails.DisplayName)"
        }
    }
}

        $script:Results += [PSCustomObject]@{
            DisplayName       = $Action.DisplayName
            UserPrincipalName = $Action.UserPrincipalName
            ActionType        = "Mover"
            ActionTaken       = "Updated attributes and assigned target groups"
            Status            = "Completed"
        }
    }
    catch {
        Write-Status "Failed to process mover $($Action.DisplayName): $($_.Exception.Message)" "Error"
        Write-Log "Failed to process mover $($Action.DisplayName): $($_.Exception.Message)"

        $script:Results += [PSCustomObject]@{
            DisplayName       = $Action.DisplayName
            UserPrincipalName = $Action.UserPrincipalName
            ActionType        = "Mover"
            ActionTaken       = "Mover update failed"
            Status            = $_.Exception.Message
        }
    }
}

function Process-Leaver {
    param ($Action)

    Write-Host ""
    Write-Status "Processing Leaver: $($Action.DisplayName)" "Info"
    Write-Log "Processing Leaver: $($Action.DisplayName)"

    $User = Get-MgUser -Filter "userPrincipalName eq '$($Action.UserPrincipalName)'" -ErrorAction SilentlyContinue

    if (!$User) {
        Write-Status "Leaver user not found: $($Action.UserPrincipalName)" "Error"
        Write-Log "Leaver user not found: $($Action.UserPrincipalName)"

        $script:Results += [PSCustomObject]@{
            DisplayName       = $Action.DisplayName
            UserPrincipalName = $Action.UserPrincipalName
            ActionType        = "Leaver"
            ActionTaken       = "User lookup failed"
            Status            = "User not found"
        }

        return
    }

    try {
        Update-MgUser `
            -UserId $User.Id `
            -AccountEnabled:$false `
            -Department $Action.Department `
            -JobTitle $Action.JobTitle `
            -ErrorAction Stop

        Write-Status "Disabled account for $($Action.DisplayName)" "Success"
        Write-Log "Disabled account for $($Action.DisplayName)"

        $MemberGroups = Get-MgUserMemberOf -UserId $User.Id

        foreach ($GroupObject in $MemberGroups) {
            if ($GroupObject.AdditionalProperties["@odata.type"] -eq "#microsoft.graph.group") {
                try {
                    Remove-MgGroupMemberByRef `
                        -GroupId $GroupObject.Id `
                        -DirectoryObjectId $User.Id `
                        -ErrorAction Stop

                    Write-Status "Removed $($Action.DisplayName) from group ID $($GroupObject.Id)" "Success"
                    Write-Log "Removed $($Action.DisplayName) from group ID $($GroupObject.Id)"
                }
                catch {
                    Write-Status "Could not remove $($Action.DisplayName) from group ID $($GroupObject.Id)" "Warning"
                    Write-Log "Could not remove $($Action.DisplayName) from group ID $($GroupObject.Id): $($_.Exception.Message)"
                }
            }
        }

        $script:Results += [PSCustomObject]@{
            DisplayName       = $Action.DisplayName
            UserPrincipalName = $Action.UserPrincipalName
            ActionType        = "Leaver"
            ActionTaken       = "Disabled user and removed group memberships"
            Status            = "Completed"
        }
    }
    catch {
        Write-Status "Failed to process leaver $($Action.DisplayName): $($_.Exception.Message)" "Error"
        Write-Log "Failed to process leaver $($Action.DisplayName): $($_.Exception.Message)"

        $script:Results += [PSCustomObject]@{
            DisplayName       = $Action.DisplayName
            UserPrincipalName = $Action.UserPrincipalName
            ActionType        = "Leaver"
            ActionTaken       = "Leaver process failed"
            Status            = $_.Exception.Message
        }
    }
}

Clear-Host

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "        JML LIFECYCLE AUTOMATION LAB           " -ForegroundColor Cyan
Write-Host "        Microsoft Entra ID + Graph             " -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

if (!(Test-Path ".\logs")) {
    New-Item -ItemType Directory -Path ".\logs" | Out-Null
}

if (!(Test-Path ".\reports")) {
    New-Item -ItemType Directory -Path ".\reports" | Out-Null
}

if (!(Test-Path $CsvPath)) {
    Write-Status "Could not find jml-actions.csv" "Error"
    exit
}

Write-Log "Starting JML lifecycle automation."

Connect-Graph

$JmlActions = Import-Csv $CsvPath

foreach ($Action in $JmlActions) {
    switch ($Action.ActionType) {
        "Joiner" {
            Create-Joiner -Action $Action
        }

        "Mover" {
            Process-Mover -Action $Action
        }

        "Leaver" {
            Process-Leaver -Action $Action
        }

        default {
            Write-Status "Unknown action type: $($Action.ActionType)" "Warning"
            Write-Log "Unknown action type: $($Action.ActionType)"
        }
    }
}

$Results | Export-Csv -Path $ReportPath -NoTypeInformation

Write-Log "JML lifecycle automation completed."

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "              JML SUMMARY                      " -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "Records processed: $($JmlActions.Count)"
Write-Host "Report: $ReportPath"
Write-Host "Log: $LogPath"
Write-Host "==============================================" -ForegroundColor Cyan