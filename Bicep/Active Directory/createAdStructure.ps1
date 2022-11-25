
Function DelegateFullControl {
    PARAM (
        $GroupSID,
        $ouDN
    )
    Write-Host $ouDN
    $ouACL = Get-Acl -Path "AD:$($ouDN)"
    
    $Identity = [System.Security.Principal.IdentityReference] ([System.Security.Principal.SecurityIdentifier] $GroupSID)
    $ADRight = [System.DirectoryServices.ActiveDirectoryRights] "GenericAll"
    $Type = [System.Security.AccessControl.AccessControlType] "Allow"
    $InheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "All"
    $Rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($Identity, $ADRight, $Type,  $InheritanceType)
    
    $ACL.AddAccessRule($Rule)
    Set-Acl -Path "AD:$($ouDN)" -AclObject $ouACL
}

Function CreateDemoGPO {
    PARAM (
        $linkOU,
        $gpoName
    )

    $gpo = New-GPO -Name $gpoName
    New-GPLink -Guid $gpo.Id -Target $linkOU
}

Function CreateDemoGroups {
    PARAM (
        $StartNo
    )

    $group = New-ADGroup "Users - $($StartNo)00-$($StartNo)99" -path $ouGroups.DistinguishedName -GroupScope DomainLocal -PassThru
    $members = Get-AdObject -LdapFilter "(samAccountName=user.no$($StartNo)*)"
    Add-ADGroupMember -Identity $group -Members $members

    $group = New-ADGroup "Computers - $($StartNo)00-$($StartNo)99" -path $ouGroups.DistinguishedName -GroupScope DomainLocal -PassThru
    $members = Get-AdObject -LdapFilter "(samAccountName=DEMOCOMP$($StartNo)*)"
    Add-ADGroupMember -Identity $group -Members $members

    $group = New-ADGroup "Servers - $($StartNo)00-$($StartNo)99" -path $ouGroups.DistinguishedName -GroupScope DomainLocal -PassThru
    $members = Get-AdObject -LdapFilter "(samAccountName=SERVER$($StartNo)*)"
    Add-ADGroupMember -Identity $group -Members $members
}

Function CreateRandomDemoGroups {
    $r = Get-Random -Minimum 5 -Maximum 100

    If ( !(Get-ADGroup -LDAPFilter "(cn=Group with $($r) random users)")) {
        $group = New-ADGroup "Group with $($r) random users" -path $ouGroups.DistinguishedName -GroupScope DomainLocal -PassThru
    
        (1..$r) | ForEach-Object {
            $member = Get-AdUser -LdapFilter "(samAccountName=user.no$( Get-Random -Minimum 100 -Maximum 999 ))"
            Add-ADGroupMember -Identity $group -Members $member
        }
    }

}

$DomainDN=(Get-ADDomain).DistinguishedName
Write-Host "Create OU structure"
$ouBase = New-ADOrganizationalUnit -Name "Demo Company" -path $DomainDN -PassThru

$ouAdmins    = New-ADOrganizationalUnit -Name "Admins"    -Path $ouBase -PassThru
$ouComputers = New-ADOrganizationalUnit -Name "Computers" -Path $ouBase -PassThru
$ouGroups    = New-ADOrganizationalUnit -Name "Groups"    -Path $ouBase -PassThru
$ouServers   = New-ADOrganizationalUnit -Name "Servers"   -Path $ouBase -PassThru
$ouUsers     = New-ADOrganizationalUnit -Name "Users"     -Path $ouBase -PassThru

Write-Host "Delegate admin groups"
$adminAdmins    = New-ADGroup "Dekegation_Admins_FullControl"    -path $ouGroups.DistinguishedName -GroupScope DomainLocal -PassThru
$adminComputers = New-ADGroup "Dekegation_Computers_FullControl" -path $ouGroups.DistinguishedName -GroupScope DomainLocal -PassThru
$adminGroups    = New-ADGroup "Dekegation_Groups_FullControl"    -path $ouGroups.DistinguishedName -GroupScope DomainLocal -PassThru
$adminServers   = New-ADGroup "Dekegation_Servers_FullControl"   -path $ouGroups.DistinguishedName -GroupScope DomainLocal -PassThru
$adminUsers     = New-ADGroup "Dekegation_Users_FullControl"     -path $ouGroups.DistinguishedName -GroupScope DomainLocal -PassThru

Write-Host "Delegate OU control"
DelegateFullControl -groupSid $adminAdmins.SID -ouDN $ouAdmins.DistinguishedName
DelegateFullControl -groupSid $adminComputers.SID -ouDN $ouComputers.DistinguishedName
DelegateFullControl -groupSid $adminGroups.SID -ouDN $ouGroups.DistinguishedName
DelegateFullControl -groupSid $adminServers.SID -ouDN $ouServers.DistinguishedName
DelegateFullControl -groupSid $adminUsers.SID -ouDN $ouUsers.DistinguishedName


Write-Host "Create user,computer and server objects"
$adForrest = (Get-ADDomain).Forrest
(100..999) | ForEach-Object {
    $params =@{
        Name = "User No$($_)" 
        GivenName = "User"
        Surname = "No$($_)"
        SamAccountName = "user.no$($_)"
        UserPrincipalName = "user.no$($_)@$($adForrest)"
        Path = "OU=Users,$($ouBase)"
        AccountPassword = ( ConvertTo-SecureString -String "SuperSecret-$($_)" -AsPlainText -Force )
        Enabled = $true
    }
    New-ADUser @params

    $params =@{
        Name = "DEMOCOMP$($_)" 
        SamAccountName = "DEMOCOMP$($_)"
        Description = "Demo Computer $($_)"
        Path = "OU=Computers,$($ouBase)"
        Enabled = $true
    }
    New-ADComputer @params

    $params =@{
        Name = "SERVER$($_)" 
        SamAccountName = "SERVER$($_)"
        Description = "Demo Server $($_)"
        Path = "OU=Servers,$($ouBase)"
        Enabled = $true
    }
    New-ADComputer @params
}


Write-Host "Create admim accounts"
(10..29) | ForEach-Object {
    $params =@{
        Name = "Admin No$($_)" 
        GivenName = "Admin"
        Surname = "No$($_)"
        SamAccountName = "admin.no$($_)"
        UserPrincipalName = "admin.no$($_)@$($adForrest)"
        Path = "OU=Admins,$($ouBase)"
        AccountPassword = ( ConvertTo-SecureString -String "SuperSecret-$($_)" -AsPlainText -Force )
        Enabled = $true
    }
    New-ADUser @params
}

Write-Host "Add admims to groups"
Add-ADGroupMember -Identity $adminAdmins -Members ( Get-AdUser -LdapFilter "(samAccountName=admin.no10)" )
Add-ADGroupMember -Identity $adminComputers -Members ( Get-AdUser -LdapFilter "(samAccountName=admin.no10)" )
Add-ADGroupMember -Identity $adminGroups -Members ( Get-AdUser -LdapFilter "(samAccountName=admin.no10)" )
Add-ADGroupMember -Identity $adminServers -Members ( Get-AdUser -LdapFilter "(samAccountName=admin.no10)" )
Add-ADGroupMember -Identity $adminUsers -Members ( Get-AdUser -LdapFilter "(samAccountName=admin.no10)" )
Add-ADGroupMember -Identity $adminAdmins -Members ( Get-AdUser -LdapFilter "(samAccountName=admin.no12)" )
Add-ADGroupMember -Identity $adminComputers -Members ( Get-AdUser -LdapFilter "(samAccountName=admin.no13)" )
Add-ADGroupMember -Identity $adminGroups -Members ( Get-AdUser -LdapFilter "(samAccountName=admin.no14)" )
Add-ADGroupMember -Identity $adminServers -Members ( Get-AdUser -LdapFilter "(samAccountName=admin.no15)" )
Add-ADGroupMember -Identity $adminUsers -Members ( Get-AdUser -LdapFilter "(samAccountName=admin.no16)" )
Add-ADGroupMember -Identity $adminAdmins -Members ( Get-AdUser -LdapFilter "(samAccountName=admin.no17)" )
Add-ADGroupMember -Identity $adminComputers -Members ( Get-AdUser -LdapFilter "(samAccountName=admin.no18)" )
Add-ADGroupMember -Identity $adminGroups -Members ( Get-AdUser -LdapFilter "(samAccountName=admin.no19)" )
Add-ADGroupMember -Identity $adminServers -Members ( Get-AdUser -LdapFilter "(samAccountName=admin.no20)" )
Add-ADGroupMember -Identity $adminUsers -Members ( Get-AdUser -LdapFilter "(samAccountName=admin.no21)" )


Write-Host "Create GPO's"
CreateDemoGPO -gpoName "GPO-Demo Company" -linkOU $ouBase
CreateDemoGPO -gpoName "GPO-Demo Company-Admins" -linkOU $ouAdmins.DistinguishedName
CreateDemoGPO -gpoName "GPO-Demo Company-Computers" -linkOU $ouComputers.DistinguishedName
CreateDemoGPO -gpoName "GPO-Demo Company-Servers" -linkOU $ouServers.DistinguishedName
CreateDemoGPO -gpoName "GPO-Demo Company-Users" -linkOU $ouUsers.DistinguishedName

Write-Host "Create Demo Groups"
(1..9) | ForEach-Object {
    CreateDemoGroups -startNo $_
    CreateRandomDemoGroups
}
