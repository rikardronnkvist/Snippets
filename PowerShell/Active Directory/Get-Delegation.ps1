PARAM (
    $exportFileName = "X:\Path\OU-Delegation.csv"
)

$paths = [string[]](Get-ADOrganizationalUnit -Filter *).DistinguishedName
$paths += (Get-ADDomain).DistinguishedName
$Result = @()

ForEach ($Path in $Paths)  {
    Write-Host $Path
    $ACLs = (Get-Acl -Path "AD:\$($Path)").Access
    ForEach($ACL in $ACLs){
        If ($ACL.IsInherited -eq $False){
            $Properties = @{
                OU = $Path
                Identity = $ACL.IdentityReference
                ADRight = $ACL.ActiveDirectoryRights
                Type = $ACL.AccessControlType
            }
            $Result += New-Object PSobject -Property $Properties
        }
    }

}

$Result | Select-Object OU, Identity, ADRight, Type| Export-Csv -Path $exportFileName -Force -NoTypeInformation
