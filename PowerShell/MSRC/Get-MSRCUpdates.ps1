[CmdLetBinding()]
PARAM (
    [string] $baseURL = "https://api.msrc.microsoft.com/cvrf/v3.0",
    [switch] $GetLatestMonth
)

$vulnTypes = @(
    "Elevation of Privilege",
    "Security Feature Bypass",
    "Remote Code Execution",
    "Information Disclosure",
    "Denial of Service",
    "Spoofing",
    "Edge - Chromium"
)

If ($GetLatestMonth.IsPresent) {
    Write-Verbose "Get latest published month from URI: $($baseURL)/updates"

    $secUpdates = (Invoke-WebRequest -Uri "$($baseURL)/updates").Content | ConvertFrom-Json
    $MonthName = ($secUpdates.value | Sort-Object InitialReleaseDate | Select-Object -Last 1).ID
} else {
    $MonthName = Get-Date -UFormat "%Y-%b"
}

$secUpdatesUri = "$($baseURL)/cvrf/$($MonthName)"
Write-Verbose "Gettings updates from URI: $($secUpdatesUri)"
$securityUpdates = Invoke-RestMethod -Uri $secUpdatesUri -Headers @{ "Accept" = "application/json" }

$allVulns = @()
foreach ($vuln in ( $securityUpdates.Vulnerability | Sort-Object CVE )) {
    Write-Verbose "Processing $($vuln.CVE)"
    [double]$cvssScore = 0.0
    if ($vuln.CVSSScoreSets.Count -gt 0) {
        [double]$cvssScore = $vuln.CVSSScoreSets[0].BaseScore
    }
 
    $Properties = [PSCustomObject] @{
        CVE = $vuln.CVE
        cvssScore = $cvssScore
        Exploited = $null
        Title = $vuln.Title.Value
        Type = $null
        ExplotationMoreLikely = $null
        PubliclyDisclosed = $null
    }

    foreach ($threat in $vuln.Threats) {

        if ($threat.Description.Value) {

            if ($threat.Type -eq 1) {
                if ($threat.Description.Value -match "Exploited:Yes") {
                    $Properties.Exploited = $true
                }
            }

            If ($threat.Description.Value -in $vulnTypes) {
                $Properties.Type = $threat.Description.Value
            }
            
            If ( $threat.Description.Value.ToLower().Contains("exploitation more likely") ) {
                $Properties.ExplotationMoreLikely = $true
            }
            
            If ( $threat.Description.Value.ToLower().Contains("publicly disclosed:yes") ) {
                $Properties.PubliclyDisclosed = $true
            }
        }
    }

    $allVulns += $Properties 
}
 
# $allVulns | Format-Table * -AutoSize
