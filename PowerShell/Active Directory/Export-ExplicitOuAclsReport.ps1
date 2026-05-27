[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputDirectory = (Join-Path -Path (Get-Location) -ChildPath 'ou-acl-report'),

    [Parameter()]
    [string]$InputJsonPath,

    [Parameter()]
    [switch]$IncludeWellKnownPrincipals
)

$ErrorActionPreference = 'Stop'

function Convert-AclEntry {
    param(
        [Parameter(Mandatory)]
        [System.DirectoryServices.ActiveDirectoryAccessRule]$AccessRule
    )

    [PSCustomObject]@{
        IdentityReference    = $AccessRule.IdentityReference.Value
        ActiveDirectoryRights = $AccessRule.ActiveDirectoryRights.ToString()
        AccessControlType    = $AccessRule.AccessControlType.ToString()
        ObjectType           = $AccessRule.ObjectType.Guid
        InheritanceType      = $AccessRule.InheritanceType.ToString()
        InheritedObjectType  = $AccessRule.InheritedObjectType.Guid
        InheritanceFlags     = $AccessRule.InheritanceFlags.ToString()
        PropagationFlags     = $AccessRule.PropagationFlags.ToString()
        IsInherited          = $AccessRule.IsInherited
    }
}

function Get-IdentityExclusionPatterns {
    param(
        [Parameter()]
        [string]$DomainNetbiosName
    )

    $domainPattern = if ([string]::IsNullOrWhiteSpace($DomainNetbiosName)) {
        '[^\\]+'
    }
    else {
        [Regex]::Escape($DomainNetbiosName)
    }

    @(
        '^NT AUTHORITY\\'
        '^BUILTIN\\'
        '^NT SERVICE\\'
        '^CREATOR OWNER$'
        '^Everyone$'
        '^Authenticated Users$'
        '^INTERACTIVE$'
        '^SYSTEM$'
        '^LOCAL SERVICE$'
        '^NETWORK SERVICE$'
        '^ANONYMOUS LOGON$'
        "^(?:$domainPattern)\\(?:Domain Admins|Enterprise Admins|Schema Admins|Administrators)$"
    )
}

function Test-ShouldExcludeAclIdentity {
    param(
        [Parameter(Mandatory)]
        [string]$IdentityReference,

        [Parameter()]
        [string]$DomainNetbiosName
    )

    $identity = $IdentityReference.Trim()
    $patterns = Get-IdentityExclusionPatterns -DomainNetbiosName $DomainNetbiosName

    foreach ($pattern in $patterns) {
        if ($identity -match $pattern) {
            return $true
        }
    }

    # Handle unresolved SID strings that should always be ignored.
    if ($identity -match '^S-1-5-32-\d+$' -or $identity -match '^S-1-5-23-548$') {
        return $true
    }

    $sid = $null
    if ($identity -like 'S-1-*') {
        try {
            $sid = [System.Security.Principal.SecurityIdentifier]::new($identity)
        }
        catch {
            $sid = $null
        }
    }
    else {
        try {
            $account = [System.Security.Principal.NTAccount]::new($identity)
            $sid = $account.Translate([System.Security.Principal.SecurityIdentifier])
        }
        catch {
            $sid = $null
        }
    }

    if ($null -eq $sid) {
        return $false
    }

    $wellKnownSidTypes = @(
        [System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid
        [System.Security.Principal.WellKnownSidType]::LocalSystemSid
        [System.Security.Principal.WellKnownSidType]::LocalServiceSid
        [System.Security.Principal.WellKnownSidType]::NetworkServiceSid
        [System.Security.Principal.WellKnownSidType]::AuthenticatedUserSid
        [System.Security.Principal.WellKnownSidType]::WorldSid
        [System.Security.Principal.WellKnownSidType]::AnonymousSid
        [System.Security.Principal.WellKnownSidType]::CreatorOwnerSid
        [System.Security.Principal.WellKnownSidType]::InteractiveSid
    )

    foreach ($sidType in $wellKnownSidTypes) {
        if ($sid.IsWellKnown($sidType)) {
            return $true
        }
    }

    # Exclude common domain-wide privileged groups by RID.
    if ($sid.Value -match '^S-1-5-21-(?:\d+-){3}(512|518|519)$') {
        return $true
    }

    return $false
}

function Get-ExplicitOuAclData {
    Import-Module ActiveDirectory -ErrorAction Stop

    $domain = Get-ADDomain
    $domainNetbiosName = $domain.NetBIOSName
    if ([string]::IsNullOrWhiteSpace($domainNetbiosName) -and -not [string]::IsNullOrWhiteSpace($domain.DNSRoot)) {
        $domainNetbiosName = $domain.DNSRoot.Split('.')[0]
    }

    $organizationalUnits = Get-ADOrganizationalUnit -Filter * -Properties DistinguishedName, Name | Sort-Object Name

    $allOuItems = foreach ($ou in $organizationalUnits) {
        $acl = Get-Acl -Path ("AD:{0}" -f $ou.DistinguishedName)
        $explicitRules = @($acl.Access | Where-Object { -not $_.IsInherited })
        $filteredRules = if ($IncludeWellKnownPrincipals) {
            $explicitRules
        }
        else {
            @($explicitRules | Where-Object {
                -not (Test-ShouldExcludeAclIdentity -IdentityReference $_.IdentityReference.Value -DomainNetbiosName $domainNetbiosName)
            })
        }

        [PSCustomObject]@{
            Name               = $ou.Name
            DistinguishedName  = $ou.DistinguishedName
            ExplicitAclCount   = $filteredRules.Count
            ExplicitAcls       = @($filteredRules | ForEach-Object { Convert-AclEntry -AccessRule $_ })
        }
    }

    $ouItems = @($allOuItems | Where-Object { $_.ExplicitAclCount -gt 0 })

    [PSCustomObject]@{
        GeneratedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        DomainDnsRoot  = $domain.DNSRoot
        DomainDn       = $domain.DistinguishedName
        ExcludedWellKnownPrincipals = (-not $IncludeWellKnownPrincipals)
        ScannedOuCount = $allOuItems.Count
        OuCount        = $ouItems.Count
        TotalExplicitAclCount = (@($ouItems | Measure-Object -Property ExplicitAclCount -Sum).Sum)
        Ous            = $ouItems
    }
}

function New-HtmlReport {
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Data,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $summaryRows = @(
        [PSCustomObject]@{ Metric = 'Generated (UTC)'; Value = $Data.GeneratedAtUtc }
        [PSCustomObject]@{ Metric = 'Domain DNS Root'; Value = $Data.DomainDnsRoot }
        [PSCustomObject]@{ Metric = 'Domain DN'; Value = $Data.DomainDn }
        [PSCustomObject]@{ Metric = 'Excluded Well-Known Principals'; Value = $(if ($null -ne $Data.ExcludedWellKnownPrincipals) { [bool]$Data.ExcludedWellKnownPrincipals } else { 'Unknown (legacy input JSON)' }) }
        [PSCustomObject]@{ Metric = 'OUs Scanned'; Value = $(if ($null -ne $Data.ScannedOuCount) { $Data.ScannedOuCount } else { $Data.OuCount }) }
        [PSCustomObject]@{ Metric = 'OUs In Report (With Explicit ACLs)'; Value = $Data.OuCount }
        [PSCustomObject]@{ Metric = 'Explicit ACL Entries'; Value = $Data.TotalExplicitAclCount }
    )

    $summaryTable = $summaryRows | ConvertTo-Html -Fragment

    $bodyBuilder = New-Object System.Text.StringBuilder
    [void]$bodyBuilder.AppendLine("<h2>Summary</h2>")
    [void]$bodyBuilder.AppendLine($summaryTable)
    [void]$bodyBuilder.AppendLine("<h2>OU Details</h2>")

    foreach ($ou in $Data.Ous) {
        $encodedName = [System.Net.WebUtility]::HtmlEncode($ou.Name)
        $encodedDn = [System.Net.WebUtility]::HtmlEncode($ou.DistinguishedName)

        [void]$bodyBuilder.AppendLine("<div class='ou-block'>")
        [void]$bodyBuilder.AppendLine("<h3>$encodedName</h3>")
        [void]$bodyBuilder.AppendLine("<p><strong>DN:</strong> $encodedDn</p>")
        [void]$bodyBuilder.AppendLine(("<p><strong>Explicit ACL Count:</strong> {0}</p>" -f $ou.ExplicitAclCount))

        if ($ou.ExplicitAclCount -gt 0) {
            $aclTable = @($ou.ExplicitAcls) | ConvertTo-Html -Fragment
            [void]$bodyBuilder.AppendLine($aclTable)
        }
        else {
            [void]$bodyBuilder.AppendLine("<p class='muted'>No explicit ACL entries found.</p>")
        }

        [void]$bodyBuilder.AppendLine("</div>")
    }

    $css = @'
body {
    font-family: Segoe UI, Arial, sans-serif;
    color: #1f2937;
    background: #f3f7fb;
    margin: 0;
    padding: 0;
}
header {
    background: linear-gradient(120deg, #0f4c81, #1b6aa8);
    color: #ffffff;
    padding: 24px 36px;
    box-shadow: 0 2px 8px rgba(15, 76, 129, 0.25);
}
main {
    padding: 24px 36px 40px;
}
h1 {
    margin: 0;
    font-size: 28px;
}
h2 {
    color: #0f4c81;
    margin-top: 28px;
}
h3 {
    margin-bottom: 8px;
    color: #1b6aa8;
}
table {
    border-collapse: collapse;
    width: 100%;
    background: #ffffff;
    border: 1px solid #d7e1ea;
    margin-top: 12px;
}
th, td {
    border: 1px solid #d7e1ea;
    padding: 8px;
    text-align: left;
    vertical-align: top;
    font-size: 13px;
}
th {
    background: #e8f1f8;
    color: #0f4c81;
}
.ou-block {
    background: #ffffff;
    border: 1px solid #d7e1ea;
    border-radius: 6px;
    padding: 16px;
    margin-bottom: 16px;
    box-shadow: 0 1px 3px rgba(31, 41, 55, 0.08);
}
.muted {
    color: #6b7280;
}
'@

    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8' />
    <title>OU Explicit ACL Report</title>
    <style>$css</style>
</head>
<body>
    <header>
        <h1>Active Directory OU Explicit ACL Report</h1>
    </header>
    <main>
$($bodyBuilder.ToString())
    </main>
</body>
</html>
"@

    Set-Content -Path $Path -Value $html -Encoding UTF8
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$data = if ($PSBoundParameters.ContainsKey('InputJsonPath')) {
    if (-not (Test-Path -Path $InputJsonPath -PathType Leaf)) {
        throw "InputJsonPath '$InputJsonPath' was not found."
    }

    Get-Content -Path $InputJsonPath -Raw | ConvertFrom-Json -Depth 10
}
else {
    Get-ExplicitOuAclData
}

$jsonPath = Join-Path -Path $OutputDirectory -ChildPath 'explicit-ou-acls.json'
$htmlPath = Join-Path -Path $OutputDirectory -ChildPath 'explicit-ou-acls-report.html'

$data | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding UTF8
New-HtmlReport -Data $data -Path $htmlPath

Write-Host ("JSON report: {0}" -f $jsonPath)
Write-Host ("HTML report: {0}" -f $htmlPath)
