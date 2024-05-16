[CmdLetBinding()]
PARAM (
    [string] $teamsWebhook = "https://xyz.webhook.office.com/webhookb2/abc123/IncomingWebhook/xyz789",
    [string] $baseURL = "https://api.msrc.microsoft.com/cvrf/v3.0",
    [switch] $GetLatestMonth
)
if(-not (Get-Module -ListAvailable PSTeams)) {
    throw "Missing module PSTeams"
}

$vulnTypes = @(
    "Elevation of Privilege",
    "Security Feature Bypass",
    "Remote Code Execution",
    "Information Disclosure",
    "Denial of Service",
    "Spoofing",
    "Edge - Chromium"
)
Function Get-VulnInfoAsText {
    PARAM (
        [Parameter(Position = 0, Mandatory = $true)]
        [array]$vuln
    )

    $retText = "- [$($vuln.CVE)](https://www.cve.org/CVERecord?id=$($vuln.CVE))"
    if ( $vuln.cvssScore -gt 0 ) {
        $retText += "- **$($vuln.cvssScore.toString("0.0"))**"
    }
    $retText += " - $($vuln.Title.Replace($vuln.CVE, ''))`r"
    $retText = $retText.Replace("  ", " ")

    Return $retText
}


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


New-AdaptiveCard -FallBackText "MSRC published CVEs for $(Get-Date -UFormat "%B %Y"), found a total of $( ($allVulns  | Measure-Object).Count ) vulnerabilities" {

    New-AdaptiveTextBlock -Size Large -Weight Bolder -Text "MSRC published CVEs for $(Get-Date -UFormat "%B %Y")"
    New-AdaptiveLineBreak

    # ----------------------------------------
    New-AdaptiveTextBlock -Size Medium -Weight Bolder -Text "Found a total of **$( ($allVulns  | Measure-Object).Count )** vulnerabilities" -Wrap
    $text = ""
    Foreach ( $vulnType in ( $allVulns | Group-Object Type | Sort-Object Count -Descending)) {
        $text += "- **$($vulnType.Count)** $($vulnType.Name) Vulnerabilities`r"
    }
    New-AdaptiveTextBlock  -Text $text -Wrap
    New-AdaptiveLineBreak

    # ----------------------------------------
    New-AdaptiveTextBlock -Size Medium -Weight Bolder -Text "Found **$( ($allVulns | Where-Object { $_.Exploited } | Measure-Object).Count )** exploited in the wild" -Wrap
    $text = ""
    Foreach ( $vuln in ($allVulns | Where-Object { $_.Exploited } | Sort-Object cvssScore -Descending ) ) {
        $text += (Get-VulnInfoAsText $vuln)
    }
    New-AdaptiveTextBlock  -Text $text -Wrap
    New-AdaptiveLineBreak

    # ----------------------------------------
    New-AdaptiveTextBlock -Size Medium -Weight Bolder -Text "Found **$( ($allVulns | Where-Object { $_.ExplotationMoreLikely } | Measure-Object).Count )** vulnerabilities more likely to be exploited" -Wrap
    $text = ""
    Foreach ( $vuln in ($allVulns | Where-Object { $_.ExplotationMoreLikely } | Sort-Object cvssScore -Descending ) ) {
        $text += (Get-VulnInfoAsText $vuln)
    }
    New-AdaptiveTextBlock  -Text $text -Wrap
    New-AdaptiveLineBreak

    # ----------------------------------------
    New-AdaptiveTextBlock -Size Medium -Weight Bolder -Text 'All CVEs' -Wrap
    $text = ""
    Foreach ( $vuln in ($allVulns | Sort-Object cvssScore -Descending ) ) {
        $text += (Get-VulnInfoAsText $vuln)
    }
    New-AdaptiveTextBlock  -Text $text -Wrap
    New-AdaptiveLineBreak

    # ----------------------------------------
} -Uri $teamsWebhook -FullWidth
