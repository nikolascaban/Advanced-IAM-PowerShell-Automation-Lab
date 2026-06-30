# Lab 01 - JML Lifecycle Automation

## Overview

This lab simulates an IAM Joiner, Mover, and Leaver lifecycle workflow using PowerShell.

The script imports mock HR user data and a role-based access map, determines the required access for each user, simulates IAM actions, writes activity to a log file, and exports an audit report.

## Skills Demonstrated

- PowerShell scripting
- CSV import with `Import-Csv`
- Joiner/Mover/Leaver IAM workflow
- Role-based access mapping
- Logging
- Audit reporting
- Error and warning handling
- Basic automation structure

## Files

| File/Folder | Purpose |
|---|---|
| `jml-lifecycle.ps1` | Main PowerShell automation script |
| `users.csv` | Mock HR user feed |
| `role-access-map.csv` | Role-based access mapping file |
| `logs/` | Stores script execution logs |
| `reports/` | Stores generated audit reports |
| `screenshots/` | Stores project screenshots |

## Screenshots

### Folder Structure

![Folder Structure](screenshots/01-folder-structure.png)

### Users CSV

![Users CSV](screenshots/02-users-csv.png)

### Role Access Map

![Role Access Map](screenshots/03-role-access-map.png)

### Initial Script Output

![Terminal Output](screenshots/04-terminal-output.png)

### Audit Report

![Audit Report](screenshots/05-audit-report.png)

### Log File

![Log File](screenshots/06-log-file.png)

### Enhanced Terminal Output

![Enhanced Terminal Output](screenshots/07-enhanced-terminal-output.png)

## What the Script Does

1. Imports user data from `users.csv`.
2. Imports role mappings from `role-access-map.csv`.
3. Matches users to required access based on department and job title.
4. Processes users based on Joiner, Mover, or Leaver status.
5. Logs all simulated IAM actions.
6. Exports an audit report.
7. Displays a processing summary.

## Example IAM Actions Simulated

- Create user account
- Add user to role-based access groups
- Validate access for movers
- Disable leaver accounts
- Remove group access
- Flag records that require review

## How to Run

Open PowerShell from this lab folder and run:

```powershell
.\jml-lifecycle.ps1
