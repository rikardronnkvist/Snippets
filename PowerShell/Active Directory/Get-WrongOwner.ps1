$ADObjects = Get-ADObject -Filter * -SearchBase "CN=XX,DC=blaha,DC=xyz"
$ADObjects = $ADObjects | Where-Object { $_.ObjectClass -notin @("dnsNode", "dnsZone", "mSSMSRoamingBoundaryRange", "printQueue") }
  
$WrongOwner = @()
$i = 0
$wrong = 0
$DNCount = $ADObjects.Count

ForEach ($ADObject in $ADObjects)  { 
    Write-Progress -Activity "Reading ACL - $($i) of $($DNCount)" -CurrentOperation "Count: $($wrong)" -Status $ADObject.DistinguishedName -PercentComplete (($i / $DNCount) * 100)
    $ACL = Get-Acl -Path "AD:\$($ADObject.DistinguishedName)"
  
    If ( $ACL.Owner -notin @("XYZ\Domain Admins", "XYZ\Enterprise Admins", "NT AUTHORITY\SYSTEM", "BUILTIN\Administrators") ) {
        $Properties = @{
            Name = $ADObject.Name
            DistinguishedName = $ADObject.DistinguishedName
            ObjectClass = $ADObject.ObjectClass
            Owner = $ACL.Owner
        }
 
        $WrongOwner += New-Object PSobject -Property $Properties
        $wrong++
    }
 
    $i++
}
 
$WrongOwner | Export-Csv -Path ".\AD-WrongOwner.csv" -Delimiter ";" -Force -NoTypeInformation -Encoding UTF8
#$WrongOwner | Format-Table -AutoSize
