[CmdLetbinding()]
PARAM (
    [String] $SafeModePassword,
    [String] $DomainName = "demo.local",
    [String] $DomainNetbiosName = "DEMO"
)

Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

Install-ADDSForest -DomainName $DomainName -ForestMode 7 -DomainMode 7 -DomainNetbiosName $DomainNetbiosName -InstallDns:$true -SafeModeAdministratorPassword (ConvertTo-SecureString $SafeModePassword -AsPlainText -Force) -Confirm:$false
