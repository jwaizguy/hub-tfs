param(
	[string] $Username,
	[string] $Password
)

$BaseUri = "https://updates.suite.blackducksoftware.com/repo/com/blackducksoftware/integration"

# Get .vsix from current directory
$Vsix = Get-ChildItem *.vsix

$Project = ("{0}-{1}" -f $Vsix.Name.Split("-")[0], $Vsix.Name.Split("-")[1])
$Release = $Vsix.Name.Split("-")[2].Replace(".vsix", "")

$Uri = New-Object System.Uri(("{0}/{1}/{2}/{3}" -f $BaseUri, $Project, $Release, $Vsix.Name))
$AF_Password = ConvertTo-SecureString $Password -AsPlainText -Force
$Creds = New-Object System.Management.Automation.PSCredential ($Username, $AF_Password)

# Copy to Artifactory
Invoke-WebRequest -Uri $Uri -InFile $Vsix -Method Put -Credential $Creds