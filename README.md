# Get-AutopilotRegistrationInformation

Check machine Autopilot registration status and profile assignment

> EXAMPLE 1: Get-AutopilotRegistrationCheck

    Start the check and display the information to screen

> EXAMPLE 2: Get-AutopilotRegistrationCheck -EventNumber 25

    Start the check and display the information to screen. Dump the last 25 events from the Windows event log

> EXAMPLE 3: Get-AutopilotRegistrationCheck -EventNumber 25 -ExportData

    Start the check and export the data to individual csv files for later user

> EXAMPLE 4: Get-AutopilotRegistrationCheck -EventNumber 25 -ExportData -Verbose

    Start the check and export the data to individual csv files for later user with verbose information
