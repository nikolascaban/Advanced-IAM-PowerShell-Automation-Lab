# Lab 01 - JML Lifecycle Automation
# Advanced IAM PowerShell Automation Lab

$UsersPath = ".\users.csv"
$RoleMapPath = ".\role-access-map.csv"
$ReportPath = ".\reports\jml-audit-report.csv"
$LogPath = ".\logs\jml-lifecycle.log"

$AuditResults = @()
$ErrorCount = 0

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

function Test-RequiredFile {
    param ([string]$Path)

    if (!(Test-Path $Path)) {
        Write-Status "Missing required file: $Path" "Error"
        Write-Log "Missing required file: $Path"
        exit
    }
}

Clear-Host

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "      JML LIFECYCLE AUTOMATION SIMULATION       " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

Write-Log "Starting JML lifecycle automation."

Test-RequiredFile $UsersPath
Test-RequiredFile $RoleMapPath

try {
    $Users = Import-Csv $UsersPath
    $RoleMap = Import-Csv $RoleMapPath
    Write-Status "CSV files imported successfully." "Success"
    Write-Log "CSV files imported successfully."
}
catch {
    Write-Status "Failed to import CSV files." "Error"
    Write-Log "Failed to import CSV files. Error: $_"
    exit
}

foreach ($User in $Users) {
    Write-Host ""
    Write-Status "Processing user: $($User.Username)" "Info"
    Write-Log "Processing user: $($User.Username)"

    if ([string]::IsNullOrWhiteSpace($User.Username)) {
        Write-Status "User record missing username." "Error"
        Write-Log "User record missing username."
        $ErrorCount++
        continue
    }

    $MatchedRole = $RoleMap | Where-Object {
        $_.Department -eq $User.Department -and $_.JobTitle -eq $User.JobTitle
    }

    if (!$MatchedRole) {
        Write-Status "No role mapping found for $($User.Username)." "Warning"
        Write-Log "No role mapping found for $($User.Username)."

        $AuditResults += [PSCustomObject]@{
            EmployeeID = $User.EmployeeID
            Username   = $User.Username
            ChangeType = $User.ChangeType
            Action     = "No matching role found"
            Status     = "Review Required"
        }

        $ErrorCount++
        continue
    }

    $Groups = $MatchedRole.RequiredGroups -split ";"

    switch ($User.ChangeType) {
        "Joiner" {
            Write-Status "Creating account for $($User.Username)." "Success"
            Write-Log "Create account for $($User.Username)."

            $AuditResults += [PSCustomObject]@{
                EmployeeID = $User.EmployeeID
                Username   = $User.Username
                ChangeType = $User.ChangeType
                Action     = "Create account"
                Status     = "Completed"
            }

            foreach ($Group in $Groups) {
                Write-Status "Adding $($User.Username) to $Group." "Success"
                Write-Log "Add $($User.Username) to $Group."

                $AuditResults += [PSCustomObject]@{
                    EmployeeID = $User.EmployeeID
                    Username   = $User.Username
                    ChangeType = $User.ChangeType
                    Action     = "Add to $Group"
                    Status     = "Completed"
                }
            }
        }

        "Mover" {
            Write-Status "Reviewing updated access for $($User.Username)." "Info"
            Write-Log "Review access for mover $($User.Username)."

            foreach ($Group in $Groups) {
                Write-Status "Validating access to $Group." "Success"
                Write-Log "Validate $($User.Username) access to $Group."

                $AuditResults += [PSCustomObject]@{
                    EmployeeID = $User.EmployeeID
                    Username   = $User.Username
                    ChangeType = $User.ChangeType
                    Action     = "Validate access to $Group"
                    Status     = "Completed"
                }
            }
        }

        "Leaver" {
            Write-Status "Disabling account for $($User.Username)." "Success"
            Write-Status "Removing all group access for $($User.Username)." "Success"

            Write-Log "Disable account for $($User.Username)."
            Write-Log "Remove all group access for $($User.Username)."

            $AuditResults += [PSCustomObject]@{
                EmployeeID = $User.EmployeeID
                Username   = $User.Username
                ChangeType = $User.ChangeType
                Action     = "Disable account and remove all access"
                Status     = "Completed"
            }
        }

        default {
            Write-Status "Unknown change type for $($User.Username): $($User.ChangeType)" "Warning"
            Write-Log "Unknown change type for $($User.Username): $($User.ChangeType)"

            $AuditResults += [PSCustomObject]@{
                EmployeeID = $User.EmployeeID
                Username   = $User.Username
                ChangeType = $User.ChangeType
                Action     = "Unknown change type"
                Status     = "Review Required"
            }

            $ErrorCount++
        }
    }
}

$AuditResults | Export-Csv -Path $ReportPath -NoTypeInformation

$JoinerCount = ($Users | Where-Object { $_.ChangeType -eq "Joiner" }).Count
$MoverCount = ($Users | Where-Object { $_.ChangeType -eq "Mover" }).Count
$LeaverCount = ($Users | Where-Object { $_.ChangeType -eq "Leaver" }).Count

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "              JML PROCESSING SUMMARY           " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Users Processed: $($Users.Count)"
Write-Host "Joiners: $JoinerCount"
Write-Host "Movers: $MoverCount"
Write-Host "Leavers: $LeaverCount"
Write-Host "Errors/Warnings: $ErrorCount"
Write-Host "Audit Report: $ReportPath"
Write-Host "Log File: $LogPath"
Write-Host "===============================================" -ForegroundColor Cyan

Write-Log "JML lifecycle automation completed."