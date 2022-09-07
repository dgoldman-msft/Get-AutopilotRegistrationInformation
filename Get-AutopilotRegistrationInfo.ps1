function Write-ErrorRecord {
    <#
    .SYNOPSIS
        Log error to disk

    .DESCRIPTION
        Log an exception to log file on disk

    .PARAMETER ExceptionCaught
        Exception caught

    .PARAMETER FailureLogFile
        Failure log file

    .PARAMETER LogPath
        Log path

    .NOTES
        None
    #>

    [CmdletBinding()]
    param (
        [System.Management.Automation.ErrorRecord]
        $ErrorRecordCaught,

        [string]
        $FailureLogFile = "$($Env:COMPUTERNAME)-FailureLog.csv",

        [string]
        $LogPath = "c:\AutopilotLogfiles"
    )

    begin {
        write-Verbose "Logging Exception"
    }

    process {
        try {
            Write-Verbose "Checking to see if $($LogPath) exists"
            if(-NOT (Test-Path -Path $LogPath)){
                Write-Verbose "Creating logging directory: $($LogPath)"
                New-Item -Path $LogPath -ItemType Directory -ErrorAction SilentlyContinue
            }

            $record = [PSCustomObject]@{
                'Failure Time'   = (Get-Date -Format "MM/dd/yyyy HH:mm:ss")
                CategoryInfo     = $ErrorRecordCaught.CategoryInfo.Category
                CategoryActivity = $ErrorRecordCaught.CategoryInfo.Activity
                CategoryTarget   = $ErrorRecordCaught.CategoryInfo.TargetName
                'Error Message'  = $ErrorRecordCaught.Exception.Message
            }
            Write-Output "Error written to log file! Please see $(Join-Path -Path $LogPath -ChildPath $FailureLogFile)."
            $record | Export-Csv -Path (Join-Path -Path $LogPath -ChildPath $FailureLogFile) -ErrorAction SilentlyContinue -ErrorVariable Failed -Encoding UTF8 -NoTypeInformation -Append
        }
        catch {
            Write-Output "ERROR: $_"
            return
        }
    }

    end {
        write-Verbose "Logging Exception finished!"
    }
}

function Get-AutopilotRegistrationInformation {
    <#
    .SYNOPSIS
        Check machines Autopilot registration state

    .DESCRIPTION
        This will dump out the local computer Autopilot information to confirm successful or unsuccessful registration to the MDE endpoint

    .PARAMETER EventNumber
        Number of events you want to capture

    .PARAMETER ExportData
        Switch to log data to log file

    .PARAMETER LogPath
        Log storage path

    .PARAMETER AutopilotRegLogFile
        Log file for AutoPilot registry information

    .PARAMETER MachineRegLogFile
        Log file for machine registry information

    .PARAMETER EventLogFile
        Log file for windows event information

    .EXAMPLE
        Get-AutopilotRegistrationCheck

        Start the check and display the information to screen

    .EXAMPLE
        Get-AutopilotRegistrationCheck -EventNumber 25

        Start the check and display the information to screen. Dump the last 25 events from the Windows event log

    .EXAMPLE
        Get-AutopilotRegistrationCheck -EventNumber 25 -ExportData

        Start the check and export the data to individual csv files for later user

    .EXAMPLE
        Get-AutopilotRegistrationCheck -EventNumber 25 -ExportData _verbose

        Start the check and export the data to individual csv files for later user with verbose information

    .NOTES
        None
    #>

    [CmdletBinding()]
    param (
        [Int]
        $EventNumber = '10',

        [switch]
        $ExportData,

        [string]
        $LogPath = "c:\AutopilotLogfiles",

        [string]
        $MachineRegLogFile = "$($Env:COMPUTERNAME)-MachineRegistryInfo.csv",

        [string]
        $AutopilotRegLogFile = "$($Env:COMPUTERNAME)-AutopilotRegistryInfo.csv",

        [string]
        $EventLogFile = "$($Env:COMPUTERNAME)-AutopilotEventLogInfo.csv"
    )

    begin {
        Write-Output "Starting Autopilot Registration Status Check"
        $parameters = $PSBoundParameters
    }

    process {
        try {
            Write-Verbose "Gathering machine registry information for: $($Env:COMPUTERNAME)"
            if ($currentVersionRegInfo = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion") {
                $machineInfo = [PSCustomObject]@{
                    BuildBranch      = $currentVersionRegInfo.BuildBranch
                    BuildLab         = $currentVersionRegInfo.BuildLab
                    CurrentBuild     = $currentVersionRegInfo.CurrentBuild
                    CurrentVersion   = $currentVersionRegInfo.CurrentVersion
                    DisplayVersion   = $currentVersionRegInfo.DisplayVersion
                    EditionID        = $currentVersionRegInfo.EditionID
                    InstallationType = $currentVersionRegInfo.InstallationType
                    ProductName      = $currentVersionRegInfo.ProductName
                    ReleaseId        = $currentVersionRegInfo.ReleaseId
                }
                $machineInfo
                Write-Output "Gathering Autopilot Registry Information"

                if ($autopilotRegInfo = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Provisioning\Diagnostics\AutoPilot' -ErrorAction SilentlyContinue -ErrorVariable RegFailure) {
                    if ($autopilotRegInfo.CloudAssignedTenantUpn -eq "") { $CloudAssignedTenantUpn = "None Assigned" } else { $CloudAssignedTenantUpn = $autopilotRegInfo.CloudAssignedTenantUpn }
                    if ($autopilotRegInfo.CloudAssignedDeviceNameLastProcessed -eq "") { $CloudAssignedDeviceNameLastProcessed = "None Assigned" } else { $CloudAssignedDeviceNameLastProcessed = $autopilotRegInfo.CloudAssignedDeviceNameLastProcessed }

                    $autoPilotInfo = [PSCustomObject]@{
                        AutopilotServiceCorrelationId           = $autopilotRegInfo.AutopilotServiceCorrelationId
                        CloudAssignedTenantDomain               = $autopilotRegInfo.CloudAssignedTenantDomain
                        CloudAssignedTenantId                   = $autopilotRegInfo.CloudAssignedTenantId
                        CloudAssignedDeviceName                 = $autopilotRegInfo.CloudAssignedDeviceName
                        CloudAssignedLanguage                   = $autopilotRegInfo.CloudAssignedLanguage
                        CloudAssignedTenantUpn                  = $CloudAssignedTenantUpn
                        CloudAssignedDeviceNameLastProcessed    = $CloudAssignedDeviceNameLastProcessed
                        CloudAssignedOobeConfig                 = $autopilotRegInfo.CloudAssignedOobeConfig
                        IsAutoPilotDisabled                     = $autopilotRegInfo.IsAutoPilotDisabled
                        isForcedEnrollmentEnabled               = $autopilotRegInfo.isForcedEnrollmentEnabled
                        PreUpdateAutopilotAgilityProductVersion = $autopilotRegInfo.PreUpdateAutopilotAgilityProductVersion
                    }
                    $autoPilotInfo
                }
                else { Write-Output "ERROR: Unable to retrieve registry information!" }

                if ( $currentVersionRegInfo.ReleaseId -eq '1803' -or $currentVersionRegInfo.ReleaseId -eq '1809') {
                    Write-Output "Gathering AutoPilot Windows Event Logs"
                    if ($events = Get-WinEvent -MaxEvents $EventNumber -LogName 'Microsoft-Windows-Provisioning-Diagnostics-Provider/AutoPilot' -ErrorAction SilentlyContinue -ErrorVariable EventFailure) { $events | Format-Table }
                }
                elseif ( $currentVersionRegInfo.ReleaseId -ge '1903') {
                    if ($events = Get-WinEvent -MaxEvents $EventNumber -LogName 'Microsoft-Windows-ModernDeployment-Diagnostics-Provider/AutoPilot' -ErrorAction SilentlyContinue -ErrorVariable EventFailure) { $events | Format-Table }
                }
            }
            else {
                Write-Output "ERROR: Unable to gather registry information! Exiting."
                return
            }
        }
        catch {
            Write-ErrorRecord -ErrorRecordCaught $_
        }

        try {
            if ($parameters.ContainsKey('ExportData')) {
                Write-Verbose "Saving registry data to $(Join-Path -Path $LogPath -ChildPath $MachineRegLogFile)"
                $machineInfo | Export-Csv -Path (Join-Path -Path $LogPath -ChildPath $MachineRegLogFile) -ErrorAction SilentlyContinue -ErrorVariable RegFailure -Encoding UTF8 -NoTypeInformation -Append
                Write-Verbose "Saving registry data to $(Join-Path -Path $LogPath -ChildPath $AutopilotRegLogFile)"
                $autoPilotInfo | Export-Csv -Path (Join-Path -Path $LogPath -ChildPath $AutopilotRegLogFile) -ErrorAction SilentlyContinue -ErrorVariable RegFailure -Encoding UTF8 -NoTypeInformation -Append
                Write-Verbose "Saving registry data to $(Join-Path -Path $LogPath -ChildPath $EventLogFile)"
                $events | Export-Csv -Path (Join-Path -Path $LogPath -ChildPath $EventLogFile) -ErrorAction SilentlyContinue -ErrorVariable EventFailure -Encoding UTF8 -NoTypeInformation -Append
            }
        }
        catch {
            Write-ErrorRecord -ErrorRecordCaught $_
        }
    }

    end {
        Write-Output "Finished Autopilot Registration Status Check. Please check $($LogPath) for more information"
    }
}