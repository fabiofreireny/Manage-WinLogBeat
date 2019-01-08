<#
.SYNOPSIS
    Helps you manage winLogBeat deployments
.DESCRIPTION
    Elastic 6.5 has built-in management of Beats agents. However, you must be a paying customer, which I'm not
    I've written this script to help me manage my winLogBeat agents

    You must create a winLogBeat folder where this script lives and place all winLogbeat files that you downloaded from Elastic there

    you must also create winLogbeat.XX.yml files, one for each type of server you collect info from. For example:
    - winLogBeat.DC.yml for Domain Controllers (included as example)
    - winLogBeat.Print.yml for Print Servers
    Adjust the $TYPE parameter to meet your needs

    The script will check the time stamp of winlogbeat.exe and winlogbeat.yml. Based on that information it will:
    - Install winLogBeat if winLogBeat.exe isn't found on the remote computer
    - Upgrade winLogBeat if the local version or the EXE is newer
    - Update winLogBeat configuration (yml file) if the local version of the YML is newer

.EXAMPLE
    PS C:\> Manage-WinLogBeat.ps1 -Targets "nydc01", "nydc02" -Type DC -Credential (Get-Credential)
    Script will prompt for local admin credentials (Domain Admin since these servers are DCs), connect to the two named servers and apply the 'DC' YML file to them

.NOTES
    https://github.com/fabiofreireny/Manage-WinLogBeat
#>

Param
(
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [String[]]$targets,

    [Parameter(mandatory=$true)]
    [ValidateSet('DC','Print','FilePrint')]
    [string]$type,

    [Parameter(mandatory=$true)]
    [pscredential]$Credential
)

begin {
    $stopService  = 'Set-ExecutionPolicy -ExecutionPolicy unrestricted; Stop-service winLogBeat -ErrorAction SilentlyContinue'
    $startService = 'Start-Service winLogBeat'
    $copyConfig   = 'Copy-Item -ToSession $session .\winLogBeat.$type.yml "c:\Program Files\winLogBeat\winLogBeat.yml" -Force'
    $copyCode     = 'Copy-Item -ToSession $session .\winLogBeat "c:\Program Files\winLogBeat\" -Recurse -Force'
    $uninstall    = 'cd "C:\Program Files\winLogBeat\"; .\uninstall-service-winlogbeat.ps1'
    $install      = 'cd "C:\Program Files\winLogBeat\"; .\install-service-winlogbeat.ps1'
}

process {
    try {
        $targets | ForEach-Object {
            $target = $_
            write-host "Configuring $target..." -NoNewline
            $session = New-PSSession -ComputerName $target -Credential $Credential

            # Find out if service already exists
            $serviceStatus = invoke-command -Session $session -ScriptBlock { get-service winlogbeat -erroraction SilentlyContinue }

            if ($serviceStatus) {
                invoke-command -Session $session -ScriptBlock { Invoke-Expression $using:stopService }

                # winlogbeat already installed
                $codeVersionDest = (invoke-command -Session $session -ScriptBlock { get-item 'c:\Program Files\winlogbeat\winlogbeat.exe' | Select-Object LastWriteTimeUTC }).LastWriteTimeUTC
                $codeVersionSource = (get-item 'winlogbeat\winlogbeat.exe' | Select-Object LastWriteTimeUTC).LastWriteTimeUTC

                if ($codeVersionDest -eq $codeVersionSource) {
                    # This might be a configuration update
                    $configVersionDest = (invoke-command -Session $session -ScriptBlock { get-item 'c:\Program Files\winlogbeat\winlogbeat.yml' | Select-Object LastWriteTimeUTC }).LastWriteTimeUTC
                    $configVersionSource = (get-item "winlogbeat.$type.yml" | Select-Object LastWriteTimeUTC).LastWriteTimeUTC

                    if ($configVersionDest -eq $configVersionSource) {
                        "Nothing to do"
                    } else {
                        "Update Configuration"
                        Invoke-Expression $copyConfig
                    }

                } else {
                    # This is an upgrade
                    "Upgrade"
                    invoke-command -Session $session -ScriptBlock { Invoke-Expression $using:uninstall }

                    Invoke-Expression $copyCode
                    Invoke-Expression $copyConfig

                    invoke-command -Session $session { Invoke-Expression $using:install }
                }
            } else {
                # This is a new install
                "New Install"
                Invoke-Expression $copyCode
                Invoke-Expression $copyConfig

                invoke-command -Session $session { Invoke-Expression $using:install }
            }
            invoke-command -Session $session { Invoke-Expression $using:startService }
        }
    }
    catch {
        $_.Exception.ItemName
        $_.Exception.Message
        "Well, that sucks"
    }
    $session | remove-pssession
}
