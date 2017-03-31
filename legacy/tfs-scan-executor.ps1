param (
    [Parameter(Mandatory=$true)][string]$HubUrl, 
    [Parameter(Mandatory=$true)][string]$HubUsername,
	[Parameter(Mandatory=$true)][string]$HubPassword,
    [Parameter(Mandatory=$true)][string]$HubProjectName,
    [Parameter(Mandatory=$true)][string]$HubRelease,
    [Parameter(Mandatory=$false)][string]$HubCodeLocationName,
    [Parameter(Mandatory=$true)][string]$HubCheckPolicies,
    [Parameter(Mandatory=$true)][string]$HubScanTimeout
)

function GetScanStatus($JsonData, $HubSession, $HubScanTimeout) {	
    #Start timer based on HubScanTimeout. If the scan has not completed in the specified amount of time, exit the script
    $Timeout = New-Timespan -Minutes $HubScanTimeout
    $SW = [Diagnostics.Stopwatch]::StartNew()
	
    while ($SW.Elapsed -lt $Timeout) {
		
        try {
            $ScanSummaryResponse = Invoke-RestMethod -Uri $JsonData._meta.href -Method Get -WebSession $HubSession
        }
        catch {
            Write-Error ("ERROR: {0}" -f $_.Exception.Response.StatusDescription)
            Exit
        }
		
        if ($ScanSummaryResponse.status -eq "COMPLETE") {
            Return
        }
        Else {
            Start-Sleep -Seconds 3
            Continue
        }
    }
    Write-Error ("ERROR: Hub Scan has timed out per configuration: {0} minutes" -f $HubScanTimeout)
    Exit
}

function CheckHubUrl($HubUrl) {
    $HTTP_Request = [System.Net.WebRequest]::Create($HubUrl)
    $HTTP_Response = $HTTP_Request.GetResponse()
	
    If ([int]$HTTP_Response.StatusCode -eq 200) { 
        Write-Output "INFO: Communication with the Hub succeeded." 
        $HTTP_Response.Close()
    }
    Else {
        Write-Error "ERROR: Communication with the Hub failed. The server may be down, or the Server URL parameter is incorrect."
        $HTTP_Response.Close()
        Exit
    }
}

$HubScannerLocation = [REPLACE WITH HUB SCANNER FILE SYSTEM LOCATION]
$LogFolder = "bds_hub_logs"
$LogOutput = "CLI_Output.txt"

#Folder Locations
$HubScannerLogsLocation = Join-path $Env:TF_BUILD_BUILDDIRECTORY $LogFolder

#Remove trailing "/" from HubUrl if it exists
if (($HubUrl.Substring($HubUrl.Length-1) -eq "/")) {
    $HubUrl = $HubUrl.Substring(0, $HubUrl.Length-1) 
}

#Ensure HubURL is correct, and connectivity can be established. 
#No point in continuing if we can't connect to the Hub.
CheckHubUrl $HubUrl

#Establish Session
try {
    Invoke-RestMethod -Uri ("{0}/j_spring_security_check" -f $HubUrl) -Method Post -Body (@{j_username=$HubUsername;j_password=$HubPassword}) -SessionVariable HubSession -ErrorAction:Stop
}
catch {
    Write-Error ("ERROR: Could not establish session - Unauthorized")
    Exit
}

#Get Hub instance version number
$HubVersion = Invoke-RestMethod -Uri ("{0}/api/v1/current-version" -f $HubUrl) -Method Get -WebSession $HubSession
Write-Output ("INFO: Black Duck Hub {0}" -f $HubVersion)

if (!(Test-Path($HubScannerLogsLocation))) {
    Write-Output ("INFO: Create Hub logs folder at: {0}" -f $HubScannerLogsLocation)
    New-Item -ItemType directory -Path $HubScannerLogsLocation | Out-Null
}

$BuildLogFolder =[System.IO.Path]::Combine($HubScannerLogsLocation, $Env:TF_BUILD_BUILDDEFINITIONNAME, $Env:TF_BUILD_BUILDNUMBER)

if (!(Test-Path($BuildLogFolder))) {
    Write-Output ("INFO: Create build specific Hub logs folder at: {0}" -f $BuildLogFolder)
    New-Item -ItemType directory -Path $BuildLogFolder | Out-Null
}

Write-Output ("INFO: Hub scan client found at: {0}" -f $HubScannerLocation)

#Get scan target
$ScanTarget = $Env:TF_BUILD_SOURCESDIRECTORY

#Execute Hub scan and write logs (for some reason it comes through the error stream)
Write-Output "INFO: Starting Black Duck Hub scan with the following parameters"
Write-Output ("INFO: Server URL: {0}" -f $HubUrl)
Write-Output ("INFO: Project Location: {0}" -f $ScanTarget)
Write-Output ("INFO: Project Name: {0}" -f $HubProjectName)
Write-Output ("INFO: Project Version: {0}" -f $HubRelease)

#If a Code Location Name is specified
if ($HubCodeLocationName) {
    Write-Output ("INFO: Code Location Name: {0}" -f $HubCodeLocationName)
    Start-Process $HubScannerLocation `
	-ArgumentList ('-username {0} -password {1} -scheme {2} -host {3} -port {4} "{5}" -project "{6}" -release "{7}" -verbose -statusWriteDir "{8}" -name "{9}" -exclude /$tf/' -f `
	$HubUsername, $HubPassword, ([System.Uri]$HubUrl).Scheme, ([System.Uri]$HubUrl).Host, ([System.Uri]$HubUrl).Port, $ScanTarget, $HubProjectName, $HubRelease, $BuildLogFolder, $HubCodeLocationName) `
	-NoNewWindow -Wait -RedirectStandardError (Join-Path $BuildLogFolder $LogOutput)
}
else {
    Start-Process $HubScannerLocation `
	-ArgumentList ('-username {0} -password {1} -scheme {2} -host {3} -port {4} "{5}" -project "{6}" -release "{7}" -verbose -statusWriteDir "{8}" -exclude /$tf/' -f `
	$HubUsername, $HubPassword, ([System.Uri]$HubUrl).Scheme, ([System.Uri]$HubUrl).Host, ([System.Uri]$HubUrl).Port, $ScanTarget, $HubProjectName, $HubRelease, $BuildLogFolder) `
	-NoNewWindow -Wait -RedirectStandardError (Join-Path $BuildLogFolder $LogOutput)
}

#Get Hub scan status, and based on it, continue or exit
$status = ((Select-String -Path (Join-Path $BuildLogFolder $LogOutput) -Pattern "ERROR: ") -split ": ")[-1]

if ($status) {
    Write-Error "ERROR: " $status
}

$DataOutputFile = ((Select-String -Path (Join-Path $BuildLogFolder $LogOutput) -Pattern " Creating data output file: ") -split ": ")[-1]

if ($HubCheckPolicies -eq "true") {
    Write-Output "INFO: Checking for Hub Policy Violations"
	
    #Re-establish Session
    try {
        Invoke-RestMethod -Uri ("{0}/j_spring_security_check" -f $HubUrl) -Method Post -Body (@{j_username=$HubUsername;j_password=$HubPassword}) -SessionVariable HubSession -ErrorAction:Stop
    }
    catch {
        Write-Error ("ERROR: {0}" -f $_.Exception.Response.StatusDescription)
        Exit
    }
	
    $JsonData = Get-Content -Raw -Path $DataOutputFile | ConvertFrom-Json
	
    #Get Scan Summary
    #Check for scan status and time out after a certain amount of minutes if status doesn't reach complete
    GetScanStatus $JsonData $HubSession $HubScanTimeout
	
    #Get Project/Version
    try {
        $ProjectVersionResponse = Invoke-RestMethod -Uri $JsonData._meta.links[0].href -Method Get -WebSession $HubSession
    }
    catch {
        Write-Error ("ERROR: {0}" -f $_.Exception.Response.StatusDescription)
        Exit
    }
    #Get Policy Status
    try {
        $PolicyResponse = Invoke-RestMethod -Uri ("{0}/policy-status" -f $ProjectVersionResponse.mappedProjectVersion) -Method Get -WebSession $HubSession
    }
    catch {
        Write-Error ("ERROR: {0}" -f $_.Exception.Response.StatusDescription)
        Exit
    }
	
	$PolicyStatus = $PolicyResponse.overallStatus
	switch ($PolicyStatus)
	{
		IN_VIOLATION { 
			Write-Error "ERROR: This release violates a Black Duck Hub policy." 
			Exit 1
		} 
		NOT_IN_VIOLATION { 
			Write-Output "INFO: This release has passed all Black Duck Hub policy rules." 
			Break
		}
		IN_VIOLATION_OVERRIDDEN { 
			Write-Output "ERROR: This release has policy violations, but they have been overridden." 
			Break
		}
		default { 
			Write-Error "ERROR: Unknown error."
			Exit 1
		}
	}
	
}

Write-Output "INFO: Black Duck Hub Scan task completed"
Write-Output ("INFO: Logs can be found at: {0}" -f $BuildLogFolder)