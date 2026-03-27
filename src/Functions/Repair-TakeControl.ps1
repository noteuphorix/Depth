function Repair-TakeControl {
# Take Control Recovery Script
# N-able Technologies 2025
# Version: 4.5.2
#
# This script checks for the installation of the Take Control agent, verifies its signature, and re-installs it if necessary.
# The script is designed to be run with administrator privileges and can be forced to re-install the agent using command line arguments.

# Parameters:
# -Force: Forces the re-installation of the Take Control agent without changing it's configuration..
# -CleanInstall: Forces a clean installation of the Take Control agent, removing any existing installations and registry keys.
# -TargetVersion: Install the specified version of the Take Control N-central agent.
# -CheckOnly: Checks the Take Control agent state without re-installing it.
# -CheckAndReInstall: Checks the Take Control agent state and re-installs it if necessary.
# -Silent: Runs the script in silent mode without user interaction.
# -DisableNewTCIntegrationCheck: Disable the new Take Control N-central agent integration check.
# -RestartNcentralAgent: Restarts the N-central agent if necessary to apply the integration change.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Re-installs the Take Control agent without changing it's configuration.")]
    [switch]$Force,    
    [Parameter(Mandatory = $false, HelpMessage = "Performs a clean install of the Take Control agent.")]
    [switch]$CleanInstall,
    [Parameter(Mandatory = $false, HelpMessage = "Checks the Take Control agent state without re-installing it.")]
    [switch]$CheckOnly,
    [Parameter(Mandatory = $false, HelpMessage = "Checks the Take Control agent state and re-installs it if necessary.")]
    [switch]$CheckAndReInstall,
    [Parameter(Mandatory = $false, HelpMessage = "Runs the script in silent mode without user interaction.")]
    [switch]$Silent,
    [Parameter(Mandatory = $false, HelpMessage = "Install the specified version of the Take Control N-central agent.")]
    [string]$TargetVersion,
    [Parameter(Mandatory = $false, HelpMessage = "Disable the new Take Control N-central agent integration check.")]
    [switch]$DisableNewTCIntegrationCheck = $false,
    [Parameter(Mandatory = $false, HelpMessage = "Restarts the N-central agent if necessary to apply the integration change.")]
    [switch]$RestartNcentralAgent = $false
)
Show-FunctionBanner "Take Control Repair"
$ScriptVersion = "4.5.2"

$agentInstallPath = Join-Path -Path ${Env:ProgramFiles(x86)} -ChildPath "Beanywhere Support Express\GetSupportService_N-central"
$agentIniPath = Join-Path -Path ${Env:ProgramData} -ChildPath "GetSupportService_N-Central\BASupSrvc.ini"
$agentRegPath = "HKLM:\SOFTWARE\WOW6432Node\Multiplicar Negocios\BACE_N-Central\Settings"
$ncentralAgentBinaryPath = Join-Path -Path ${Env:ProgramFiles(x86)} -ChildPath "N-able Technologies\Windows Agent\bin"
$ncentralAgentConfigPath = Join-Path -Path ${Env:ProgramFiles(x86)} -ChildPath "N-able Technologies\Windows Agent\config\RCConfig.xml"

if ($env:PROCESSOR_ARCHITECTURE -eq "x86") {
    $agentInstallPath = Join-Path ${Env:ProgramFiles} "Beanywhere Support Express\GetSupportService_N-central"
    $agentRegPath = "HKLM:\SOFTWARE\Multiplicar Negocios\BACE_N-Central\Settings"
    $ncentralAgentBinaryPath = Join-Path ${Env:ProgramFiles} "N-able Technologies\Windows Agent\bin"
    $ncentralAgentConfigPath = Join-Path -Path ${Env:ProgramFiles} -ChildPath "N-able Technologies\Windows Agent\config\RCConfig.xml"
}

$AgentBinaryPath = Join-Path $agentInstallPath "BASupSrvc.exe"
$UpdaterBinaryPath = Join-Path $agentInstallPath "BASupSrvcUpdater.exe"
$AgentUninstallerPath = Join-Path $agentInstallPath "UnInstall.exe" 
$IncorrectServiceName = "BASupportExpressStandaloneService"
$AgentServiceName = "BASupportExpressStandaloneService_N_Central"
$UpdaterServiceName = "BASupportExpressSrvcUpdater_N_Central"
$InstallLockFilePath = Join-Path $agentInstallPath "__installing.lock"
$UnInstallLockFilePath = Join-Path $agentInstallPath "__uninstalling.lock"
$NCentralAgentRemoteControlDLLPath = Join-Path $ncentralAgentBinaryPath "RemoteControl.dll"
$NCentralAgentConfigValueXPath = '/RCConfig/mspa_install_check_intervall'
$NCentralWindowsAgentService = "Windows Agent Service"


$RemoteJsonUrl = "https://swi-rc.cdn-sw.net/n-central/updates/json/TakeControlCheckAndReInstall.json"

if ($TargetVersion -and ($TargetVersion -notmatch '^\d+\.\d+\.[a-zA-Z0-9-_]+$')) {
    Write-Host "Invalid TargetVersion format. Please use X.Y.Z format."
    Return 1
}

if ($TargetVersion -ne "") {
    $RemoteJsonUrl = "https://swi-rc.cdn-sw.net/n-central/updates/json/TakeControlCheckAndReInstall_$TargetVersion.json"
}

$ExpectedSignedSubject = "CN=N-ABLE TECHNOLOGIES LTD, O=N-ABLE TECHNOLOGIES LTD, L=Dundee, C=GB"

$serviceNotRunningGuardInterval = 10
$lockFileAgeThresholdMinutes = 10

$LogFilePath = Join-Path $env:TEMP "TakeControlCheckAndReInstall.log"

function WriteLog {
    param (
        [Parameter(Mandatory)]
        [string]$Message,
        [ValidateSet("", "INFO", "WARN", "ERROR")]
        [string]$Level = "INFO",
        [Parameter(Mandatory = $false)]
        [string]$ForegroundColor = "White",
        [Parameter(Mandatory = $false)]
        [bool]$LogToConsole = !$Silent
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp][$Level] $Message"

    if ($LogToConsole) {
        
        # Write to console
        switch ($Level) {
            "INFO" { Write-Host $logEntry -ForegroundColor $ForegroundColor }
            "WARN" { Write-Host $logEntry -ForegroundColor DarkYellow }
            "ERROR" { Write-Host $logEntry -ForegroundColor DarkRed }
        }

    }

    # Write to log file
    try {
        Add-Content -Path $LogFilePath -Value $logEntry
    }
    catch {
        Write-Host "Failed to write to log file: $LogFilePath"
    }
}

function CheckFileSignature {
    param (
        [string]$FilePath
    )

    $result = $false

    try {

        $signature = Get-AuthenticodeSignature -FilePath $FilePath

        if ($signature.Status -eq "Valid") {

            if ($signature.SignerCertificate.Subject -eq $ExpectedSignedSubject) {
                $result = $true
            }
            else {
                WriteLog -Level "ERROR" -Message  "The file has a valid signature but is not signed by N-able."
            }

        }
        else {
            WriteLog -Level "ERROR" -Message  "The file does not have a valid signature."
        }

    }
    catch {
        WriteLog -Level "ERROR" -Message  "Error: Unable to retrieve signature information for the file."
    }

    return $result

}

function FetchTakeControlAgent {

    $validRequest = $false

    try {

        WriteLog -Message  "Fetching latest Take Control agent information..."
        $ProgressPreference = 'SilentlyContinue'
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        $jsonContent = Invoke-RestMethod -Uri $RemoteJsonUrl
        $validRequest = $true

    }
    catch {
        WriteLog -Level "ERROR" -Message  "Exception occurred while retrieving the remote json file. $($_.Exception.Message)"
    }

    if ($validRequest) { 
      
        try {

            $Url = $jsonContent.url;
            $ExpectedHash = $jsonContent.expected_hash
            $ExpectedSize = $jsonContent.expected_size

        }
        catch {
            WriteLog -Level "ERROR" -Message  "Exception occurred while parsing the remote json file. $($_.Exception.Message)"
            $validRequest = $false
        }
 
        if (($Url -ne "") -and ($ExpectedHash -ne "") -and ($validRequest)) {

            $uniqueId = [System.Guid]::NewGuid().ToString()

            $FilePath = Join-Path $env:TEMP "MSPA4NCentralInstaller-$uniqueId.exe"

            Remove-Item -Path $FilePath -ErrorAction SilentlyContinue

            WriteLog -Message  "Fetching Take Control agent binary from '$Url' to '$FilePath'."
            Invoke-WebRequest -Uri $Url -OutFile $FilePath

            WriteLog -Message  "Verifying the hash of the downloaded file."
            $ActualHash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash

            $ActualSize = (Get-Item -Path $FilePath).Length

            if ($ExpectedSize -ne $ActualSize) {
                WriteLog -Level "ERROR" -Message  "The file size does not match the expected size. Returning..."
                return $null
            } 
            elseif ($ExpectedHash -ne $ActualHash) {
                WriteLog -Level "ERROR" -Message  "The file hash does not match the expected hash. Returning..."
                return $null
            }
            elseif (-not (CheckFileSignature($FilePath))) {
                WriteLog -Level "ERROR" -Message  "The file signature is not valid. Returning..."   
                return $null
            }
            else {
                WriteLog -Message  "The file size and hash match the expected values and the signature is correct."

                return $FilePath
            }

        }
        else {
            WriteLog -Level "ERROR" -Message  "Empty URL or expected_hash."
        }

    }
    else {
        WriteLog -Level "ERROR" -Message  "Unable to retrieve the remote json file."
    }

    return $null

}

function ExecuteBinary {
    param (
        [string] $FileName,
        [string] $Parameters,
        [bool] $RemoveFile = $true
    )

    $ReturnCode = -1

    try {

        $proc = Start-Process -FilePath $FileName -ArgumentList $Parameters -Wait -PassThru -NoNewWindow -ErrorAction Stop
        $ReturnCode = $proc.ReturnCode

    }
    catch {
        WriteLog -Level "ERROR" -Message  "Error executing file `$FileName: $($_.Exception.Message)"
        $ReturnCode = 1
    }

    if ($RemoveFile) {
       
        try {
            if (Test-Path -Path $FileName) {
                WriteLog -Message  "Deleting file:`t$FileName"
                Remove-Item -Path $FileName
            }
        }
        catch {
            WriteLog -Level "WARN" -Message  "Error deleting file `$FileName`: $($_.Exception.Message)"
        }  
    
    }

    return $ReturnCode

}

function RemoveAgentIniAndRegKeyIfPresent {

    if (Test-Path -Path $agentIniPath) {
        try {
            Remove-Item -Path $agentIniPath -Force -ErrorAction Stop
            WriteLog -Message  "Successfully deleted file:`t$agentIniPath"
        }
        catch {
            WriteLog -Level "WARN" -Message  "Error deleting file `$agentIniPath`: $_"
        }
    }

    if (Test-Path -Path $agentRegPath) {
        try {
            Remove-Item -Path $agentRegPath -Recurse -Force -ErrorAction Stop
            WriteLog -Message  "Successfully deleted registry key:`t$agentRegPath"
        }
        catch {
            WriteLog -Level "WARN" -Message  "Error deleting registry key `t$agentRegPath`: $_"
        }
    }

}

function Get-IniContent {
    param(
        [Parameter(Mandatory)][string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    $ini = @{}
    $currentSection = ''

    foreach ($rawLine in Get-Content $Path) {
        $line = $rawLine.Trim()
        if ($line -match '^\s*;') {
            # skip comments
            continue
        }
        elseif ($line -match '^\[(.+)\]$') {
            # section header
            $currentSection = $Matches[1]
            if (-not $ini.ContainsKey($currentSection)) {
                $ini[$currentSection] = @{}
            }
        }
        elseif ($line -match '^(.*?)=(.*)$') {
            # key = value
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()
            if ($currentSection) {
                $ini[$currentSection][$key] = $value
            }
            else {
                # keys before any section go at top level
                $ini[$key] = $value
            }
        }
    }

    return $ini
}

function IsLockFilePresent {
    param (
        [Parameter(Mandatory = $true)]
        [string]$LockFilePath,
        [Parameter(Mandatory = $false)]
        [int]$lockFileAgeThresholdMinutes = 10
    )

    $lockExists = $false

    if (Test-Path -Path $LockFilePath) {
        $installLockFileCreationTime = (Get-Item -Path $LockFilePath).CreationTime
        $ageMinutes = (Get-Date) - $installLockFileCreationTime
        if ($ageMinutes.TotalMinutes -lt $lockFileAgeThresholdMinutes) {
            WriteLog -Message  "The lock file '$LockFilePath' is newer than $lockFileAgeThresholdMinutes minutes. Returning..."
            $lockExists = $true
        }
        else {
            WriteLog -Message  "The lock file '$LockFilePath' is older than $lockFileAgeThresholdMinutes minutes."
        }
    }

    return $lockExists

}

function WaitForLockFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$LockFilePath,
        [Parameter(Mandatory = $false)]
        [int]$WaitTimeInSeconds = 30
    )

    $endTime = (Get-Date).AddSeconds($WaitTimeInSeconds)

    while ((Get-Date) -lt $endTime) {
        if (IsLockFilePresent -LockFilePath $LockFilePath) {
            return $true
        }

        Start-Sleep -Seconds 5
    }

    return $false
}

function TerminateProcessList {
    param (
        [Parameter(Mandatory = $true)]
        [array]$ProcessList
    )

    foreach ($process in $ProcessList) {
        try {
            Get-Process -Name $process.Name -ErrorAction SilentlyContinue | Where-Object { $_.Path -ieq $process.Path } | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        catch {
            WriteLog -Level "WARN" -Message  "Error terminating process '$($process.Name)': $_"
        }
    }

}

function CheckNCentralRemoteControlDLLVersion {
    param (
        [Parameter(Mandatory = $false)]
        [string]$NCentralAgentRemoteControlDLLPath = $NCentralAgentRemoteControlDLLPath
    )

    if (Test-Path -Path $NCentralAgentRemoteControlDLLPath) {
        $dllVersion = [Version](Get-Item -Path $NCentralAgentRemoteControlDLLPath).VersionInfo.FileVersion
        WriteLog -Message  "N-central Agent Remote Control DLL version: $dllVersion"

        $minAffectedVersion = [Version]"2024.6.0.0"
        $maxAffectedVersion = [Version]"2024.6.0.22"

        if ($dllVersion -ge $minAffectedVersion -and $dllVersion -le $maxAffectedVersion) {
            WriteLog -Level "WARN" -Message  "The detected RemoteControl.DLL of the N-central Agent is known to be affected by a documented issue. Please refer to N-central's documentation to update it to the latest version."
        }

    }
    else {
        WriteLog -Level "WARN" -Message  "N-central Remote Control DLL not found at path: $NCentralAgentRemoteControlDLLPath"
    }

}

# Set TC NC integration version
function ConfigValueToVersion($ConfigValue) {
    return $(if ($ConfigValue -le 0) { 2 } else { 1 })
}

function VersionToConfigValue($Version) {
    return $(if ($Version -eq 2) { 0 } else { 15000 })
}

function GetTCIntegrationVersion() {

    if (-not (Test-Path -Path $ncentralAgentConfigPath)) {
        throw "N-central agent configuration file not found at path: $ncentralAgentConfigPath"
    }

    $xml = [System.Xml.XmlDocument]::new()
    $xml.Load($ncentralAgentConfigPath)

    if ($null -ne $xml.SelectSingleNode($ncentralAgentConfigValueXPath)) {
        WriteLog -Level "INFO" -Message "Found N-central agent Take Control integration configuration."
        return ConfigValueToVersion($xml.SelectSingleNode($ncentralAgentConfigValueXPath).InnerText)
    }
    else {
        throw "N-central agent Take Control integration configuration not found."
    }

}

function SetTCIntegrationVersion($Version) {

    if (-not (Test-Path -Path $ncentralAgentConfigPath)) {
        throw "N-central agent configuration file not found at path: $ncentralAgentConfigPath"
    }

    if (-not (Test-Path -Path $NCentralAgentRemoteControlDLLPath)) {
        WriteLog -Level "ERROR" -Message "N-central Remote Control DLL not found at path: $NCentralAgentRemoteControlDLLPath"
        return
    }

    $remoteControlInfo    = Get-Item -Path $NCentralAgentRemoteControlDLLPath | Select-Object -ExpandProperty VersionInfo
    $remoteControlVersion = [Version]$remoteControlInfo.FileVersion   
    WriteLog -Level "INFO" -Message  "N-central Agent Remote Control DLL version: $remoteControlVersion"

    $RemoteControlMinVersion = [Version]"2025.4.0.0"
    if ($remoteControlVersion -lt $RemoteControlMinVersion) {
        WriteLog -Level "WARN" -Message "N-central agent version $($remoteControlVersion.ProductVersion) is less than the minimum required $RemoteControlMinVersion for enabling the new integration, please upgrade the N-central Windows agent first."
        return
    }

    WriteLog -Level "INFO" -Message "Setting integration version to $Version"
    $xml = [System.Xml.XmlDocument]::new()
    $xml.Load($ncentralAgentConfigPath)
    $xml.SelectSingleNode($ncentralAgentConfigValueXPath).InnerText = VersionToConfigValue($Version)
    $xml.Save($ncentralAgentConfigPath)

}

function CheckAndEnableNewTCIntegration() {

    if (Test-Path -Path $ncentralAgentConfigPath) {

        try {

            $currentIntegrationVersion = GetTCIntegrationVersion

            WriteLog -Level "INFO" -Message "Current Take Control integration version: $currentIntegrationVersion"
            if ($currentIntegrationVersion -ne 2) {

                WriteLog -Level "INFO" -Message "Enabling enhanced Take Control recovery..."
                SetTCIntegrationVersion -Version 2

                if ($RestartNcentralAgent) {
                    if (ServiceExists -ServiceName $NCentralWindowsAgentService) {
                        WriteLog -Level "INFO" -Message "Restarting N-central agent service..."
                        StopService -ServiceName $NCentralWindowsAgentService -WaitTimeInMinutes 3
                        Start-Service -Name $NCentralWindowsAgentService
                        WriteLog -Level "INFO" -Message "N-central agent service restarted."
                    }
                    else {
                        WriteLog -Level "WARN" -Message "N-able N-central Agent service not found, cannot restart."
                    }
                }

            }

        }
        catch {
            WriteLog -Level "ERROR" -Message  "Error : $($_.Exception.Message)"
        }

    }

}

function IsNcentralRCConfigValid {

    if (Test-Path -Path $ncentralAgentConfigPath) {

        try {

            $xmlContent = [xml](Get-Content -Path $ncentralAgentConfigPath)

            if (($null -ne $xmlContent.RCConfig.mspa_server_unique_id) -and ($null -ne $xmlContent.RCConfig.mspa_secret_key) -and ($xmlContent.RCConfig.mspa_server_unique_id -ne "") -and ($xmlContent.RCConfig.mspa_secret_key -ne "") ) {
                return $true
            }
            else {
                WriteLog -Level "WARN" -Message  "N-central Remote Control configuration not found or incomplete."
                return $false
            }

        }
        catch {
            WriteLog -Level "ERROR" -Message  "Error reading N-central Remote Control configuration file: $($_.Exception.Message)"
        }

    }
    else {
        WriteLog -Level "WARN" -Message  "N-central Remote Control configuration file not found at path: $ncentralAgentConfigPath"
    }

    return $false

}


function  TestGatewayTCPConnection {
    param (
        [Parameter(Mandatory = $false)]
        [string]$GwTCPHost = "gw-tcp-test.global.mspa.n-able.com",
        [Parameter(Mandatory = $false)]
        [int]$GwTCPPort = 443,
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 5000  # 5 seconds
    )

    $connectionSuccess = $false
    $command = "PING"

    try {

        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $tcpClient.Connect($GwTCPHost, $GwTCPPort)
        $networkStream = $tcpClient.GetStream()

        $networkStream.ReadTimeout = $Timeout
        $networkStream.WriteTimeout = $Timeout

        $reader = New-Object System.IO.StreamReader($networkStream)
        $writer = New-Object System.IO.StreamWriter($networkStream)
        $writer.AutoFlush = $true

        try {

            $writer.WriteLine($command)

            $response = $reader.ReadLine()

            if ($response -match "200 OK") {
                WriteLog -Message  "Take Control GW_TCP_$GwTCPPort is reachable. `t[200 - OK]" -ForegroundColor DarkGreen
                $connectionSuccess = $true
            }
            else {
                WriteLog -Level "WARN" -Message  "Take Control GW_TCP_$GwTCPPort is reachable with errors. `t[$response - UNEXPECTED RESPONSE]"
            }

        }
        catch {
            WriteLog -Level "WARN" -Message  "Take Control GW_TCP_$GwTCPPort is NOT reachable. `t[ERROR] - $($_.Exception.Message)"            
        }
        finally {
            $reader.Close()
            $writer.Close()
            $tcpClient.Close()
        }

    }
    catch {
        WriteLog -Level "WARN" -Message  "Take Control GW_TCP_$GwTCPPort is NOT reachable. `t[ERROR] - $($_.Exception.Message)"            
    }   

    return $connectionSuccess
    
}

function  TestGatewayTLSConnection {
    param (
        [Parameter(Mandatory = $false)]
        [string]$GwTLSHost = "gw-tls-test.global.mspa.n-able.com",
        [Parameter(Mandatory = $false)]
        [int]$GwTLSPort = 443,
        [Parameter(Mandatory = $false)]
        [int]$Timeout = 5000  # 5 seconds
    )

    $connectionSuccess = $false
    $command = "PING"

    try {

        $tcpClient = New-Object System.Net.Sockets.TcpClient($GwTLSHost, $GwTLSPort)
        $networkStream = $tcpClient.GetStream()

        $sslStream = New-Object System.Net.Security.SslStream($networkStream, $false, { $true })
        $sslStream.AuthenticateAsClient($GwTLSHost, $null, [System.Security.Authentication.SslProtocols]::Tls12, $false)

        $sslStream.ReadTimeout = $Timeout
        $sslStream.WriteTimeout = $Timeout

        $reader = New-Object System.IO.StreamReader($sslStream)
        $writer = New-Object System.IO.StreamWriter($sslStream)
        $writer.AutoFlush = $true

        try {
            
            $writer.WriteLine($command)

            $response = $reader.ReadLine()

            if ($response -match "200 OK") {
                WriteLog -Message  "Take Control GW_TLS_443 is reachable. `t[200 - OK]" -ForegroundColor DarkGreen
                $connectionSuccess = $true
            }
            else {
                WriteLog -Level "WARN" -Message  "Take Control GW_TLS_443 is reachable with errors. `t[$response - UNEXPECTED RESPONSE]"
            }

        }
        catch {
            WriteLog -Level "WARN" -Message  "Take Control GW_TLS_443 is NOT reachable. `t[ERROR] - $($_.Exception.Message)"            
        }
        finally {
            $reader.Close()
            $writer.Close()
            $sslStream.Close()
            $tcpClient.Close()
        }

    }
    catch {
        WriteLog -Level "WARN" -Message  "Take Control GW_TLS is NOT reachable. `t[ERROR] - $($_.Exception.Message)"            
    }

    return $connectionSuccess

}

function TestTakeControlInfrastructureConnection {

    $HTTPQueryList = @(
        @{ Region = "GLB"; URL = "https://comserver.global.mspa.n-able.com/comserver/echo.php?magicid=query_global"; ExpectedValue = "<response><echo>query_global</echo></response>" },
        @{ Region = "US1"; URL = "https://comserver.us1.mspa.n-able.com/comserver/echo.php?magicid=query_us1"; ExpectedValue = "<response><echo>query_us1</echo></response>" },
        @{ Region = "US2"; URL = "https://comserver.us2.mspa.n-able.com/comserver/echo.php?magicid=query_us2"; ExpectedValue = "<response><echo>query_us2</echo></response>" },
        @{ Region = "EU1"; URL = "https://comserver.eu1.mspa.n-able.com/comserver/echo.php?magicid=query_eu1"; ExpectedValue = "<response><echo>query_eu1</echo></response>" },
        @{ Region = "CDN"; URL = "https://swi-rc.cdn-sw.net/n-central/scripts/echo.xml"; ExpectedValue = "<response><echo>query_cdn</echo></response>" }
    )

    $connectionError = $false

    foreach ($httpQuery in $HTTPQueryList) {

        try {

            $ProgressPreference = 'SilentlyContinue'           
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $response = Invoke-WebRequest -Uri $httpQuery.URL -UseBasicParsing -ErrorAction Stop

            if ($response.Content -eq $httpQuery.expectedValue) {
                WriteLog -Message  "Take Control $($httpQuery.Region) is reachable. `t`t[$($response.StatusCode) - OK]" -ForegroundColor DarkGreen
            }
            else {
                WriteLog -Level "WARN" -Message  "Take Control $($httpQuery.Region) is reachable with errors. `t`t[$($response.StatusCode) - UNEXPECTED RESPONSE]"
            }

        }
        catch {
            WriteLog -Level "WARN" -Message  "Take Control $($httpQuery.Region) is NOT reachable. `t`t[ERROR] - $($_.Exception.Message)"            
            $connectionError = $true
        }

    }

    $gwTCPResult = TestGatewayTCPConnection
    $gwTCPResult3377 = TestGatewayTCPConnection -GwTCPPort 3377
    $gwTLSResult = TestGatewayTLSConnection

    if ((-not $gwTCPResult) -and (-not $gwTCPResult3377) -and (-not $gwTLSResult)) {
        $connectionError = $true
    }
    
    if ($connectionError -eq $true) {
        WriteLog -Level "WARN" -Message  "`nTake Control infrastructure may not be reachable. Please check this device's internet connection and firewall settings and make sure connections to the Take Control infrastructure are not being blocked. Please refer to the Take Control documentation for more information.`n"
    }
    
}

function CheckLockFileAndReInstall {
    param (
        [Parameter(Mandatory = $false)]
        [bool]$CleanInstall = $false
    )

    $lockExists = IsLockFilePresent -LockFilePath $InstallLockFilePath -lockFileAgeThresholdMinutes $lockFileAgeThresholdMinutes
    if ($lockExists -eq $true) {
        WriteLog -Message  "Installation lock file is present. Returning..."
        Return
    }

    $lockExists = IsLockFilePresent -LockFilePath $UnInstallLockFilePath -lockFileAgeThresholdMinutes $lockFileAgeThresholdMinutes
    if ($lockExists -eq $true) {
        WriteLog -Message  "Uninstallation lock file is present. Returning..."
        Return
    }

    WriteLog -Message  "Fetching Take Control agent location..."
    $agentFile = FetchTakeControlAgent
    $mspID = $null

    if ($null -ne $agentFile) {

        if ($CleanInstall -eq $true) {

            WriteLog -Message  "Reading ini file content..."
            $iniContent = Get-IniContent -Path $agentIniPath

            if ($null -eq $iniContent) {
                WriteLog -Message  "No ini file found..."
            }
            else {
                if ($iniContent.ContainsKey("Main") -and $iniContent["Main"].ContainsKey("MSPID")) {                 
                    $mspID = $iniContent["Main"]["MSPID"]
                    WriteLog -Message  "MSPID: $mspID"
                }
                else {
                    WriteLog -Level "WARN" -Message  "No MSPID found in ini file..."
                }
            }

            # Remove Take Control service with incorrect name if present
            if (ServiceExists -ServiceName $IncorrectServiceName) {

                if (CheckServiceExecutablePath -ServiceName $IncorrectServiceName -ExpectedPath $AgentBinaryPath) {

                    WriteLog -Message  "Found TC N-central agent with incorrect service name $IncorrectServiceName..."
                    $serviceStopped = StopService -ServiceName $IncorrectServiceName -WaitTimeInMinutes 3

                    if (-not $serviceStopped) {
                        WriteLog -Level "WARN" -Message  "Take Control service $IncorrectServiceName did not stop within the expected time."
                    } else {

                        WriteLog -Message  "Removing incorrect Take Control service $IncorrectServiceName..."
                        if (DeleteService -ServiceName $IncorrectServiceName) {
                            WriteLog -Message  "Successfully removed incorrect Take Control service $IncorrectServiceName."
                        }
                        else {
                            WriteLog -Level "WARN" -Message  "Error removing incorrect Take Control service $IncorrectServiceName."
                        }

                    }

                }
               
            }

            if (Test-Path $AgentUninstallerPath) {

                $lockExists = IsLockFilePresent -LockFilePath $UnInstallLockFilePath -lockFileAgeThresholdMinutes $lockFileAgeThresholdMinutes
                if ($lockExists -eq $true) {
                    WriteLog -Message  "Uninstallation lock file is present. Uninstallation is in progress... Returning..."
                    Return
                }

                WriteLog -Message  "Uninstalling previous agent..."

                $uninstallerArguments = "/S"
                $ReturnCode = ExecuteBinary -FileName $AgentUninstallerPath -Parameters $uninstallerArguments
                WriteLog -Message "Uninstaller finished with Return code $ReturnCode"

            }
            else {
                WriteLog -Level "WARN" -Message  "Take Control agent uninstaller not found..."
            }

            WriteLog -Message  "Making sure the Take Control agent is not running..."
            if (ServiceExists -ServiceName $AgentServiceName) {
                WriteLog -Message  "Stopping Take Control service  $AgentServiceName..."
                StopService -ServiceName $AgentServiceName -WaitTimeInMinutes 3
            }

            if (ServiceExists -ServiceName $UpdaterServiceName) {
                WriteLog -Message  "Stopping Take Control service  $UpdaterServiceName..."
                StopService -ServiceName $UpdaterServiceName -WaitTimeInMinutes 3
            }

            $processList = @(
                @{ Name = "BASupSrvc"; Path = $AgentBinaryPath },
                @{ Name = "BASupSrvcUpdater"; Path = $UpdaterBinaryPath }
            )

            WriteLog -Message  "Terminating any running services..."
            TerminateProcessList -ProcessList $processList

            WriteLog -Message  "Cleaning up previous installation..."
            RemoveAgentIniAndRegKeyIfPresent

        }

        $parameters = "/S /R /L"
        if (($null -ne $mspID) -and ($mspID -ne "")) {
            $parameters += " /MSPID $mspID"
        }

        WriteLog -Message  "Checking for the presence of install lock file..."
        $lockExists = WaitForLockFile -LockFilePath $InstallLockFilePath -WaitTimeInSeconds 45
        if ($lockExists -eq $true) {
            WriteLog -Message  "Installation lock file is present. Installation is already in progress... Returning..."
            Return
        }

        WriteLog -Message  "Starting Take Control agent installer"
        $ReturnCode = ExecuteBinary -FileName $agentFile -Parameters $parameters
        WriteLog -Message "Installer finished with Return code $ReturnCode"

    }
    else {
        WriteLog -Level "ERROR" -Message ("Unable to download Take Control agent file...")  
    }

    Return

}

function ServiceExists {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName
    )

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        return $false
    } 

    return $true

}

function WaitForServiceState {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,

        [Parameter(Mandatory = $true)]
        [string]$ExpectedState,

        [Parameter(Mandatory = $true)]
        [int]$WaitTimeInMinutes,

        [Parameter(Mandatory = $false)]
        [int]$ServicePollIntervalSeconds = 5
    )

    $endTime = (Get-Date).AddMinutes($WaitTimeInMinutes)

    while ((Get-Date) -lt $endTime) {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

        if (($null -ne $service) -and ($service.Status -eq $ExpectedState)) {
            WriteLog -Message  "Service '$ServiceName' is in the '$ExpectedState' state."
            return $true
        }

        Start-Sleep -Seconds $servicePollIntervalSeconds
    }

    WriteLog -Message  "Service '$ServiceName' did not reach the '$ExpectedState' state within the specified wait time."
    return $false

}

function WaitForServiceToStart {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,

        [Parameter(Mandatory = $true)]
        [int]$WaitTimeInMinutes
    )

    WaitForServiceState -ServiceName $ServiceName -ExpectedState "Running" -WaitTimeInMinutes $WaitTimeInMinutes

}

function StopService {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,

        [Parameter(Mandatory = $true)]
        [int]$WaitTimeInMinutes
    )

    if (-not (ServiceExists -ServiceName $ServiceName)) {
        WriteLog -Level "WARN" -Message  "Service '$ServiceName' does not exist."
        return $false
    }

    try {

        Stop-Service -Name $ServiceName -ErrorAction Stop

    }
    catch {
        WriteLog -Level "WARN" -Message  "Error stopping service '$ServiceName': $_"
        return $false
    }

    $retVal = WaitForServiceState -ServiceName $ServiceName -ExpectedState "Stopped" -WaitTimeInMinutes $WaitTimeInMinutes

    return $retVal
}

function DeleteService {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName
    )

    if (-not (ServiceExists -ServiceName $ServiceName)) {
        WriteLog -Level "WARN" -Message  "Service '$ServiceName' does not exist."
        return $false
    }

    try {

        sc.exe delete $ServiceName | Out-Null

    }
    catch {
        WriteLog -Level "WARN" -Message  "Error deleting service '$ServiceName': $($_.Exception.Message)"
        return $false
    }

    return $true

}

function CheckServiceExecutablePath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,
        [Parameter(Mandatory = $true)]
        [string]$ExpectedPath
    )

    $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue

    if ($null -eq $service) {
        return $false
    }

    try {

        $wmiService = Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'" -ErrorAction Stop
        $actualPath = $wmiService.PathName.Trim('"')

        if ($actualPath -ieq $ExpectedPath) {
            WriteLog -Message  "The service '$ServiceName' executable path matches the expected path."
            return $true
        }
        else {
            WriteLog -Level "WARN" -Message  "The service '$ServiceName' executable path does not match the expected path."
            return $false
        }

    }
    catch {
        WriteLog -Level "ERROR" -Message  "Error retrieving service information for '$ServiceName': $_"
        return $false
    }

}

## Perform Take Control agent state checks | return $true if the agent is in a good state, otherwise return $false
function IsTakeControlAgentInGoodState {
    param (
        [Parameter(Mandatory = $false)]
        [bool]$RestartServiceIfStopped = $false
    )

    WriteLog -Message "Checking Take Control agent state..."
    if ((-not (Test-Path -Path $AgentBinaryPath)) -or (-not (Test-Path -Path $UpdaterBinaryPath))) {

        WriteLog -Level ERROR -Message "Take Control agent binaries were not found..."
        return $false

    }
    else {

        WriteLog -Message "Take Control agent binaries were found..." -ForegroundColor DarkGreen

    }

    WriteLog -Message "Checking Take Control agent signatures..."
    if (-not (CheckFileSignature -FilePath $AgentBinaryPath)) {
        WriteLog -Level "ERROR" -Message  "Take Control agent binary signature is invalid."
        return $false
    }
    else {
        WriteLog -Message "Take Control agent binary signature is valid." -ForegroundColor DarkGreen
    }

    if (-not (CheckFileSignature -FilePath $UpdaterBinaryPath)) {
        WriteLog -Level "ERROR" -Message  "Take Control updater binary signature is invalid."
        return $false
    }
    else {
        WriteLog -Message "Take Control updater binary signature is valid." -ForegroundColor DarkGreen
    }

    $agentService = Get-Service -Name $AgentServiceName -ErrorAction SilentlyContinue
    if (-not $agentService) {

        WriteLog -Level ERROR -Message "The service '$AgentServiceName' is not registered..."
        return $false

    }
    else {

        WriteLog -Message "The service '$AgentServiceName' is registered..." -ForegroundColor DarkGreen

    }

    $updaterService = Get-Service -Name $UpdaterServiceName -ErrorAction SilentlyContinue
    if (-not $updaterService) {

        WriteLog -Level ERROR -Message "The service '$UpdaterServiceName' is not registered."
        return $false

    }
    else {

        WriteLog -Message  "The service '$UpdaterServiceName' is registered..." -ForegroundColor DarkGreen

    }

    if ($agentService.Status -ne "Running") {

        if ($RestartServiceIfStopped) {

            WriteLog -Message  "The service '$AgentServiceName' is not running... Waiting..."
            
            Start-Service -Name $AgentServiceName
            $agentServiceStarted = WaitForServiceToStart -ServiceName $AgentServiceName -WaitTimeInMinutes $serviceNotRunningGuardInterval
            if ($agentServiceStarted -eq $false) {
                WriteLog -Level ERROR -Message "The service '$AgentServiceName' is still not running... Re-Installing..."
                return $false
            }
            else {
                WriteLog -Message  "The service '$AgentServiceName' started... Skipping re-installation..."
            }

        }
        else {

            WriteLog -Level ERROR -Message  "The service '$AgentServiceName' is not running..."
            return $false

        }

    }
    else {

        WriteLog -Message  "The service '$AgentServiceName' is running..." -ForegroundColor DarkGreen

    }

    if ($updaterService.Status -ne "Running") {  

        if ($RestartServiceIfStopped) {

            WriteLog -Message  "The service '$UpdaterServiceName' is not running... Waiting..."
            $updaterServiceStarted = WaitForServiceToStart -ServiceName $UpdaterServiceName -WaitTimeInMinutes $serviceNotRunningGuardInterval
            if ($updaterServiceStarted -eq $false) {
                WriteLog -Message  "The service '$UpdaterServiceName' is still not running... Re-Installing..."
                return $false
            }
            else {
                WriteLog -Message  "The service '$UpdaterServiceName' started... Skipping re-installation..."
            }

        }
        else {

            WriteLog -Message  "The service '$UpdaterServiceName' is not running..."
            return $false

        }
 
    }
    else {

        WriteLog -Message  "The service '$UpdaterServiceName' is running..." -ForegroundColor DarkGreen

    }

    return $true

}

## Main Script Execution
WriteLog -Message  "Take Control Check and Re-Install Script v'$ScriptVersion'" -ForegroundColor DarkCyan
WriteLog -Message  "N-able Technologies 2025" -ForegroundColor DarkMagenta
WriteLog -Message  "------------------------------------------------------------"

if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    WriteLog -Message "This script must be run with Administrator privileges."
    Return
} 

WriteLog -Message "Testing Take Control infrastructure connection..."
TestTakeControlInfrastructureConnection

WriteLog -Message "Checking N-Central agent RemoteControl.dll version..."
CheckNCentralRemoteControlDLLVersion

if ($DisableNewTCIntegrationCheck -ne $true) {

    WriteLog -Message "Checking and enabling new Take Control integration if needed..."
    CheckAndEnableNewTCIntegration

}

if ($Force) {

    WriteLog -Message "Forcing re-installation of Take Control..."
    CheckLockFileAndReInstall -CleanInstall $false    

}

if ($CleanInstall) {

    WriteLog -Message "Performing clean installation of Take Control..."  
    CheckLockFileAndReInstall -CleanInstall $true

}

if ($CheckOnly) {

    WriteLog -Message "Checking Take Control agent state without re-installing..."
    $isInGoodState = IsTakeControlAgentInGoodState -RestartServiceIfStopped $false
    if ($isInGoodState) {
        WriteLog -Message "Take Control agent is in a good state."
        $isRCConfigValid = IsNcentralRCConfigValid
        if (-not $isRCConfigValid) {
            WriteLog -Level "WARN" -Message "N-central Remote Control configuration is not found or incomplete. Re-installing..."
            Return 1
        }
        else {
            WriteLog -Message "N-central Remote Control configuration is complete."
            Return 0
        }
    }
    else {
        WriteLog -Level "ERROR" -Message "Take Control agent is not in a good state. Please check the logs for more details."
        Return 1
    }

}

if ($CheckAndReInstall) {

    WriteLog -Message "Checking Take Control agent state and re-installing if necessary..."
    $agentInGoodState = IsTakeControlAgentInGoodState -RestartServiceIfStopped $false
    if (-not $agentInGoodState) {
        WriteLog -Level ERROR -Message "Take Control agent is not in a good state. Re-installing..."
        CheckLockFileAndReInstall -CleanInstall $true
    }
    else {

        $isRCConfigValid = IsNcentralRCConfigValid
        if (-not $isRCConfigValid) {
            WriteLog -Level "ERROR" -Message "N-central Remote Control configuration is not found or incomplete. Re-installing..."
            CheckLockFileAndReInstall -CleanInstall $true
        }
        else {
            WriteLog -Message "N-central Remote Control configuration is found and complete."
        }

        WriteLog -Message "Take Control agent is in a good state. No re-installation needed."
    }

    Return 0

}
else {

    WriteLog -Message "Checking Take Control agent state and installing if necessary..."

    $agentInGoodState = IsTakeControlAgentInGoodState -RestartServiceIfStopped $true
    if (-not $agentInGoodState) {

        WriteLog -Level ERROR -Message "Take Control agent is not in a good state. Installing..."
        CheckLockFileAndReInstall -CleanInstall $false

    }
    else {

        $isRCConfigValid = IsNcentralRCConfigValid
        if (-not $isRCConfigValid) {
            WriteLog -Level "WARN" -Message "N-central Remote Control configuration is not found or incomplete. Re-installing..."
            CheckLockFileAndReInstall -CleanInstall $true
        }
        else {
            WriteLog -Message "N-central Remote Control configuration is found and complete."
        }

        WriteLog -Message "Take Control agent is in a good state. No re-installation needed."

    }
    
}
}