param(
	[Parameter(Mandatory=$true)][string] $HubUsername,
	[Parameter(Mandatory=$true)][string] $HubPassword,
	[Parameter(Mandatory=$true)][string] $HubScheme,
	[Parameter(Mandatory=$true)][string] $HubHost,
	[Parameter(Mandatory=$true)][string] $HubPort,
	[Parameter(Mandatory=$true)][string] $HubProjectName,
	[Parameter(Mandatory=$true)][string] $HubRelease,
	[Parameter(Mandatory=$true)][string] $HubFailOnPolicyViolation,
	[Parameter(Mandatory=$true)][string] $HubScanTimeout
)

######################FUNCTIONS######################
#https://github.com/TotalALM/VSTS-Tasks/blob/master/Tasks/Unzip/task/unzip.ps1
function UnZip($zipPath, $folderPath)
{
    Add-Type -Assembly "System.IO.Compression.FileSystem" ;
    [System.IO.Compression.ZipFile]::ExtractToDirectory("$zipPath", "$folderPath") ;
    
    Start-Sleep -m 4000
    
    If (Test-Path $zipPath){
	    Remove-Item $zipPath
    }
}
#https://github.com/TotalALM/VSTS-Tasks/blob/master/Tasks/Unzip/task/unzip.ps1
function RemoveZip($zip)
{ 

start-Sleep -m 4000
If (Test-Path $zip){
	    Remove-Item $zip -Recurse -Force
    }
}

function GetScanStatus($jsonData, $HubSession, $HubScanTimeout) 
{	
	#Start timer based on HubScanTimeout. If the scan has not completed in the specified amount of time, exit the script
	$Timeout = New-Timespan -Minutes $HubScanTimeout
	$SW = [Diagnostics.Stopwatch]::StartNew()
	
	while ($SW.Elapsed -lt $Timeout){
		
		try {
			$ScanSummaryResponse = Invoke-RestMethod -Uri $jsonData._meta.href -Method Get -WebSession $HubSession
		}
		catch {
			Write-Error "ERROR:" $_.Exception.Response.StatusDescription
			Exit
		}
		
		switch ($ScanSummaryResponse.status)
		{
			UNSTARTED { 
				Start-Sleep -Seconds 3
				Continue 
			} 
			SCANNING { 
				Start-Sleep -Seconds 3
				Continue 
			}
			SAVING_SCAN_DATA { 
				Start-Sleep -Seconds 3
				Continue 
			}
			SCAN_DATA_SAVE_COMPLETE { 
				Start-Sleep -Seconds 3
				Continue 
			}
			REQUESTED_MATCH_JOB { 
				Start-Sleep -Seconds 3
				Continue 
			}
			MATCHING { 
				Start-Sleep -Seconds 3
				Continue 
			}
			BOM_VERSION_CHECK { 
				Start-Sleep -Seconds 3
				Continue 
			}
			BUILDING_BOM { 
				Start-Sleep -Seconds 3
				Continue 
			}
			COMPLETE { 
				Return
			}
			default { 
				Write-Error "ERROR:" $ScanSummaryResponse.status
				Exit
			}
		}
	}
	Write-Error "ERROR: Hub Scan has timed out per configuration:" $HubScanTimeout " minutes"
	Exit
}
#####################################################

#Constants
$HostedCli = "download/scan.cli-windows.zip"
$ScanParent = "bds_hub_scanner"
$ScanChild = "scan.cli*"
$LogFolder = "bds_hub_logs"
$LogOutput = "CLI_Output.txt"
$HubScanScript = "scan.cli.bat"

#Folder Locations
$HubScannerParentLocation = Join-Path $env:AGENT_HOMEDIRECTORY $ScanParent
$HubScannerChildLocation = Join-Path $HubScannerParentLocation $ScanChild
$HubScannerLogsLocation = Join-path $env:AGENT_HOMEDIRECTORY $LogFolder

#Determine if Hub scan client exists in the Agent home directory. If not, download it from the Hub instance.
if(!(Test-Path($HubScannerChildLocation)))
{
	Write-Host "INFO: Hub scan client not found, create folder at:" $HubScannerParentLocation
	New-Item -ItemType directory -Path $HubScannerParentLocation | Out-Null
	$WC = New-Object System.Net.WebClient
	$CliUrl = ("{0}://{1}:{2}/{3}" -f $HubScheme, $HubHost, $HubPort, $HostedCli)
	$Filename = [System.IO.Path]::GetFileName($CliUrl)
	$Output = Join-Path $HubScannerParentLocation $Filename
	Write-Host "INFO: Downloading Hub scan client from:" $CliUrl
	$WC.DownloadFile($CliUrl, $Output)
	
	if (Test-Path($Output)) { 
		Write-Host "INFO: Extracting Hub scan client"
		UnZip $Output $HubScannerParentLocation
	}
	else {
		Write-Error "ERROR: Error downloading Hub scan client"
		Exit
	}
}

if (!(Test-Path($HubScannerLogsLocation)))
{
	Write-Host "INFO: Create Hub logs folder at:" $HubScannerLogsLocation
	New-Item -ItemType directory -Path $HubScannerLogsLocation | Out-Null
}

$BuildLogFolder =[System.IO.Path]::Combine($HubScannerLogsLocation, $env:BUILD_DEFINITIONNAME, $env:BUILD_BUILDNUMBER)
if (!(Test-Path($BuildLogFolder)))
{
	Write-Host "INFO: Create build specific Hub logs folder at:" $BuildLogFolder
	New-Item -ItemType directory -Path $BuildLogFolder | Out-Null
}

$HubScannerChildLocation = Join-Path $HubScannerParentLocation  (Get-ChildItem $HubScannerParentLocation -name)
Write-Host "INFO: Hub scan client found at: " $HubScannerChildLocation

#Execute Hub scan and write logs (for some reason it comes through the error stream)
Write-Host "INFO: Starting Black Duck Hub scan with the following parameters:"
Write-Host "INFO: Username:" $HubUsername
Write-Host "INFO: Password: <NOT SHOWN>" 
Write-Host "INFO: Scheme:" $HubScheme
Write-Host "INFO: Host:" $HubHost
Write-Host "INFO: Port:" $HubPort
Write-Host "INFO: Project Location:" $env:BUILD_SOURCESDIRECTORY
Write-Host "INFO: Project Name:" $HubProjectName
Write-Host "INFO: Project Version:" $HubRelease

Start-Process -FilePath ("{0}\bin\{1}" -f $HubScannerChildLocation, $HubScanScript) `
-ArgumentList ('-username {0} -password {1} -scheme {2} -host {3} -port {4} "{5}" -project "{6}" -release "{7}" -verbose -statusWriteDir "{8}"' -f `
$HubUsername, $HubPassword, $HubScheme, $HubHost, $HubPort, $env:BUILD_SOURCESDIRECTORY, $HubProjectName, $HubRelease, $BuildLogFolder) `
-NoNewWindow -Wait -RedirectStandardError (Join-Path $BuildLogFolder $LogOutput) 

#Get Hub scan status, and based on it, continue or exit
$status = ((Select-String -Path (Join-Path $BuildLogFolder $LogOutput) -Pattern " with status ") -split " ")[-1]

switch ($status)
{
	SUCCESS { 
		Write-Host "INFO: Hub scan completed successfully" 
	} 
	FILE_NOT_FOUND { 
		Write-Error "ERROR: The archive or directory does not exist." 
		Exit
	}
	NO_HOST { 
		Write-Error "ERROR: The specified host does not exist." 
		Exit
	}
	NO_PERMISSION { 
		Write-Error "ERROR: You do not have sufficient permissions to perform the operation." 
		Exit
	}
	NO_REGISTRATION { 
		Write-Error "ERROR: The Black Duck Hub license registration has expired, the license is not registered for scanning, or you have exceeded the amount of code you are licensed to scan." 
		Exit
	}
	NO_USER { 
		Write-Error "ERROR: The specified user does not exist." 
		Exit
	}
	SOFTWARE { 
		Write-Error "ERROR: An internal software error has been detected." 
		Exit
	}
	default { 
		Write-Error "ERROR: Unknown error."
		Exit
	}
}

$DataOutputFile = ((Select-String -Path (Join-Path $BuildLogFolder $LogOutput) -Pattern " Creating data output file: ") -split ": ")[-1]

if ($HubFailOnPolicyViolation -eq "true") {
	Write-Host "INFO: Checking for Hub Policy Violations"
	
	#Login / Establish Session
	$HubLoginUrl = ("{0}://{1}:{2}/j_spring_security_check?j_username={3}&j_password={4}" -f $HubScheme, $HubHost, $HubPort, $HubUsername, $HubPassword)
	$jsonData = Get-Content -Raw -Path $DataOutputFile | ConvertFrom-Json
	try {
		Invoke-RestMethod -Uri $HubLoginUrl -Method Post -SessionVariable HubSession -ErrorAction:Stop
	}
	catch {
		Write-Error "ERROR: " $_.Exception.Response.StatusDescription
		Exit
	}
	
	#Get Scan Summary
	#Check for scan status and time out after a certain amount of minutes if status doesn't reach complete
	GetScanStatus $jsonData $HubSession $HubScanTimeout
	
	#Get Project/Version
	try {
		$ProjectVersionResponse = Invoke-RestMethod -Uri $jsonData._meta.links[0].href -Method Get -WebSession $HubSession
	}
	catch {
		Write-Error "ERROR:" $_.Exception.Response.StatusDescription
		Exit
	}
	#Get Policy Status
	try {
		$PolicyResponse = Invoke-RestMethod -Uri ("{0}/policy-status" -f $ProjectVersionResponse.mappedProjectVersion) -Method Get -WebSession $HubSession
	}
	catch {
		Write-Error "ERROR:" $_.Exception.Response.StatusDescription
		Exit
	}
	
	$PolicyStatus = $PolicyResponse.overallStatus
	switch ($PolicyStatus)
	{
		IN_VIOLATION { 
			Write-Error "ERROR: This release violates a Black Duck Hub policy." 
			Exit
		} 
		NOT_IN_VIOLATION { 
			Write-Host "INFO: This release has passed all Black Duck Hub policy rules." 
			Break
		}
		IN_VIOLATION_OVERRIDDEN { 
			Write-Host "ERROR: This release has policy violations, but they have been overridden." 
			Break
		}
		default { 
			Write-Error "ERROR: Unknown error."
			Exit
		}
	}
	
}

Write-Host "INFO: Black Duck Hub Scan task completed"
Write-Host "INFO: Logs can be found at:" $BuildLogFolder

