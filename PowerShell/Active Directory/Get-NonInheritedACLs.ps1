Function Get-NonInheritedACLs {
    $OUs = (Get-ADOrganizationalUnit -Filter *).DistinguishedName
    $OUs += (Get-ADDomain).DistinguishedName

    $NonInheritedACLs = @()

    $OUs | ForEach-Object {
        Write-Verbose $_

        $AclAccess = (Get-Acl -Path "AD:\$($_)").Access

        ForEach($ACL in $AclAccess){
            If ($ACL.IsInherited -eq $False){
            
                $NonInheritedACLs += New-Object PSobject -Property @{
                    OU = $_
                    Identity = $ACL.IdentityReference
                    ADRight = $ACL.ActiveDirectoryRights
                    Type = $ACL.AccessControlType
                }

               Write-Verbose "   $($ACL.IdentityReference) ($($ACL.AccessControlType) - $($ACL.ActiveDirectoryRights))"
            }
        }
    }

    Return $NonInheritedACLs 
}
