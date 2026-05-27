[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [string]$domainName = "ABC",
    [string[]]$IncludedObjectTypes = @(
        "user",
        "group",
        "computer",
        "organizationalUnit"
    ),
    [string[]]$searchOUs = @(
        "OU=Admin,DC=abc,DC=se",
        "OU=Company,DC=abc,DC=se",
        "OU=Autopilot_Computers,DC=abc,DC=se",
        "OU=Domain Controllers,DC=abc,DC=se",
        "OU=DisabledObjects,DC=abc,DC=se"
    ),
    $exportPath = ".\changedObjects.csv"
)

Import-Module ActiveDirectory

$newOwner = [Security.Principal.NTAccount]("$domainName\Domain Admins")

$allowedOwners = @(
    "$domainName\Domain Admins",
    "$domainName\Enterprise Admins",
    "NT AUTHORITY\SYSTEM",
    "BUILTIN\Administrators"
)

$i = 0
$start = Get-Date
$changedObjects = @()

$adObjects = @()
foreach ($ou in $searchOUs) { 
    $LdapQuery = "(|"
    $IncludedObjectTypes | ForEach-Object { 
        $LdapQuery += "(objectClass=$_)"
    }
    $LdapQuery += ")"
    Write-Host "Reading AD-objects in $ou" -ForegroundColor Cyan
    $adObjects += Get-ADObject -LDAPFilter $LdapQuery -SearchBase $ou
}

$dnCount = $adObjects.Count

foreach ($adObject in $adObjects) {
    $distinguishedName = $adObject.DistinguishedName
    $percent = if ($dnCount -gt 0) { ($i / $dnCount) * 100 } else { 0 }

    Write-Progress -Activity "Checking ACL" -Status "$($i + 1) of $dnCount" -CurrentOperation "Reading: $distinguishedName" -PercentComplete $percent

    $acl = Get-Acl -Path "AD:$distinguishedName" -ErrorAction SilentlyContinue

    if (-not $acl) {
        Write-Progress -Activity "Checking ACL" -Status "$($i + 1) of $dnCount" -CurrentOperation "Not found: $distinguishedName" -PercentComplete $percent
    }
    elseif ($acl.Owner -notin $allowedOwners) {
        $oldOwner = $acl.Owner
        $targetOwner = $newOwner.Value
        if ($PSCmdlet.ShouldProcess($distinguishedName, "Set owner to $targetOwner")) {
            Write-Progress -Activity "Checking ACL" -Status "$($i + 1) of $dnCount" -CurrentOperation "Fixing owner: $($acl.Owner) -> $newOwner" -PercentComplete $percent
            $acl.SetOwner($newOwner)
            Set-Acl -Path "AD:$distinguishedName" -AclObject $acl
            $changedObjects += [PSCustomObject]@{
                DistinguishedName = $distinguishedName
                OldOwner          = $oldOwner
                NewOwner          = $targetOwner
            }
        }
        else {
            Write-Progress -Activity "Checking ACL" -Status "$($i + 1) of $dnCount" -CurrentOperation "Would fix owner: $($acl.Owner) -> $newOwner" -PercentComplete $percent
        }
    }
    else {
        Write-Progress -Activity "Checking ACL" -Status "$($i + 1) of $dnCount" -CurrentOperation "OK: $distinguishedName" -PercentComplete $percent
    }

    $i++
}

Write-Progress -Activity "Checking ACL" -Completed

Write-Host "-----------------------------------------------------------"
Write-Host "Changed ACL objects: $($changedObjects.Count)"
if ($changedObjects.Count -gt 0) {
    Write-Host "Changed DistinguishedNames:"
    $changedObjects | Select-Object -ExpandProperty DistinguishedName | Sort-Object -Unique | ForEach-Object {
        Write-Host $_
    }
}
Write-Host "-----------------------------------------------------------"

Write-Host "Exporting changed objects to $exportPath" -ForegroundColor Green
$changedObjects | Export-Csv -Path $exportPath -Delimiter ";" -Force -NoTypeInformation -Encoding UTF8


Write-Host "Start: $( Get-Date $start -Format "yyyy-MM-dd HH:mm:ss" )"
Write-Host "Done: $( Get-Date (Get-Date) -Format "yyyy-MM-dd HH:mm:ss" )"
