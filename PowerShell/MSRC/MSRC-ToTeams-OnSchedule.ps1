[CmdLetBinding()]
PARAM (
    [string] $teamsWebhook = "https://xyz.webhook.office.com/webhookb2/abc123/IncomingWebhook/xyz789",
    [string] $baseURL = "https://api.msrc.microsoft.com/cvrf/v3.0",
    [int] $DaysAfterPatchTuesday = 1
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

Function Get-PatchTuesday {
    $firstDayOfMonth = Get-Date -Day 1

    (0..7) | ForEach-Object {
        if ($firstDayOfMonth.AddDays($_).DayOfWeek -eq "Tuesday") {
            Return Get-Date -Day ($_ + 8)
        }        
    }
}

Function Get-VulnInfoAsText {
    PARAM (
        [Parameter(Position = 0, Mandatory = $true)]
        [array]$vuln
    )

    $retText = "- [$($vuln.CVE)](https://www.cve.org/CVERecord?id=$($vuln.CVE))"
    if ( $vuln.cvssScore -gt 0 ) {
        $retText += "- **$($vuln.cvssScore.toString("0.0"))**"
    }
    $retText += " - $($vuln.Title)`r"

    Return $retText
}

Function New-CardTextblock {
    PARAM (
        [Parameter(Position = 0, Mandatory = $true)][string]$Text,
        [Parameter(Position = 1, Mandatory = $false)][switch]$Heading
    )

    $block =  @{
        "type" = "TextBlock"
        "wrap" = $True
        "text" = $Text
    }

    if ($Heading.IsPresent) {
        $block += @{
            "size" ="Medium"
            "weight"= "Bolder"
        }    
    }

    Return $block
}
# --------------------------------------------------------------------------------

If ( (Get-PatchTuesday).AddDays($DaysAfterPatchTuesday).Date -ne (Get-Date).Date ) {
    Write-Host "Wrong day - Running only on $( (Get-PatchTuesday).AddDays($DaysAfterPatchTuesday).Date ) ($($DaysAfterPatchTuesday) days after Patch Tuesday)"
    Exit
}

# --------------------------------------------------------------------------------

$MonthName = Get-Date -UFormat "%Y-%b"
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

# ----------------------------------------
$adaptiveCard = @{
    "type" = "message"
    "summary" = "MSRC published CVEs for $(Get-Date -UFormat "%B %Y")"
    "attachments" = @(
        @{
            "contentType" = "application/vnd.microsoft.card.adaptive"
            "fallbackText" = "MSRC published CVEs for $(Get-Date -UFormat "%B %Y"), found a total of $( ($allVulns  | Measure-Object).Count ) vulnerabilities"
            "content" = @{
                '$schema' = "http://adaptivecards.io/schemas/adaptive-card.json"
                "version" = "1.3"
                "type" = "AdaptiveCard"
                "msteams" = @{
                    "width" = "Full"
                }
                "body" = @(
                    @{
                        "type" = "TextBlock"
                        "size" ="large"
                        "style"= "Heading"
                        "text" = "**MSRC published CVEs for $(Get-Date -UFormat "%B %Y")**"
                        "wrap" = $true
                    }
                )
            }
        }
    )
}

# ----------------------------------------
$adaptiveCard.attachments.content.body += New-CardTextblock "Found a total of **$( ($allVulns  | Measure-Object).Count )** vulnerabilities" -Heading

$text = ""
Foreach ( $vulnType in ( $allVulns | Group-Object Type | Sort-Object Count -Descending)) {
    $text += "- **$($vulnType.Count)** $($vulnType.Name) Vulnerabilities`r"
}
$text += "`r`r"
$adaptiveCard.attachments.content.body += New-CardTextblock $text
# ----------------------------------------

$adaptiveCard.attachments.content.body += New-CardTextblock "Found **$( ($allVulns | Where-Object { $_.Exploited } | Measure-Object).Count )** exploited in the wild" -Heading

$text = ""
Foreach ( $vuln in ($allVulns | Where-Object { $_.Exploited } | Sort-Object cvssScore -Descending ) ) {
    $text += (Get-VulnInfoAsText $vuln)
}
$text += "`r`r"
$adaptiveCard.attachments.content.body += New-CardTextblock $text

# ----------------------------------------
$adaptiveCard.attachments.content.body += New-CardTextblock "Found **$( ($allVulns | Where-Object { $_.ExplotationMoreLikely } | Measure-Object).Count )** vulnerabilities more likely to be exploited" -Heading
$text = ""
Foreach ( $vuln in ($allVulns | Where-Object { $_.ExplotationMoreLikely } | Sort-Object cvssScore -Descending ) ) {
    $text += (Get-VulnInfoAsText $vuln)
}
$text += "`r`r"
$adaptiveCard.attachments.content.body += New-CardTextblock $text

# ----------------------------------------
$adaptiveCard.attachments.content.body += New-CardTextblock "All CVEs" -Heading
$text = ""
Foreach ( $vuln in ($allVulns | Sort-Object cvssScore -Descending ) ) {
    $text += (Get-VulnInfoAsText $vuln)
}
$text += "`r`r"
$adaptiveCard.attachments.content.body += New-CardTextblock $text

# ----------------------------------------

$jsonAdaptiveCard = $adaptiveCard | ConvertTo-Json -Depth 100 -Compress

Invoke-RestMethod -Method post -ContentType "Application/Json" -Body $jsonAdaptiveCard -Uri $teamsWebhook
