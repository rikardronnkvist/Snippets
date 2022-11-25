[CmdLetbinding()]
PARAM (
    [String] $UserName = "riro",
    [String] $UserPassword = "SuperSecretPassword123",
    [String] $DomainName = "demo.local",
    [String] $DomainNetbiosName = "DEMO",

    [String] $ResoureceGroupName = "rg-onprem-ad",
    [String] $ResoureceGroupLocation = "West Europe"
)

if (! (Get-AzContext)) {
    Connect-AzAccount
}

$rg = New-AzResourceGroup -Name $ResoureceGroupName -Location $ResoureceGroupLocation

$HomeCurrentIP = (Invoke-WebRequest -Uri "https://api.ipify.org").Content.Trim()
$TemplateParams = @{
    onpremAdAdminUsername = $UserName
    onpremAdAdminPassword = $UserPassword
    onpremAdDomainName = $DomainName
    onpremAdDomainNetbiosName = $DomainNetbiosName
    nsgAllowedIP = $HomeCurrentIP
    vmSize = "Standard_B4ms"
}

$deploymentName = "OnPremAD_$( Get-Date -Format 'yyyy-MM-dd' )"
$Deployment = New-AzResourceGroupDeployment -ResourceGroupName $rg.ResourceGroupName -Name $deploymentName -TemplateFile .\main.bicep -TemplateParameterObject $TemplateParams -Verbose

$PublicIP = (Get-AzPublicIpAddress -ResourceGroupName $rg.ResourceGroupName -Name $Deployment.Outputs.publicIpName.value).IpAddress
$vmResourceName = $Deployment.Outputs.VMName.value

$commandSettings = @{
    ResourceGroupName = $ResoureceGroupName
    VMName = $vmResourceName
    CommandId = 'RunPowerShellScript'
    ScriptPath = "$PWD\createAdStructure.ps1"
}
Invoke-AzVMRunCommand @commandSettings

Write-Host "Domain Controller is soon available at"
Write-Host "  RDP:   mstsc /V:$($PublicIP):3389"
