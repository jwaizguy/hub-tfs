param(
	[string] $Username,
	[string] $Password
)

$BaseUri = "https://updates.suite.blackducksoftware.com/repo/com/blackducksoftware/integration"
$Project = "hub-tfs"
$Release = "0.1.0"
$Vsix = ("{0}-{1}.vsix" -f $Project, $Release)
$Uri = New-Object System.Uri(("{0}/{1}/{2}/{3}" -f $BaseUri, $Project, $Release, $Vsix))
$AF_Password = ConvertTo-SecureString $Password -AsPlainText -Force
$Creds = New-Object System.Management.Automation.PSCredential ($Username, $AF_Password)
# Copy to Artifactory
Invoke-WebRequest -Uri $Uri -InFile $Vsix -Method Put -Credential $Creds