[CmdLetbinding()]
PARAM (
    [String] $UserName = "riro",
    [String] $UserPassword = "SuperSecretPassword123",
    [String] $DomainName = "demo.local",
    [String] $DomainNetbiosName = "DEMO"
)

if (! (Get-AzContext)) {
    Connect-AzAccount
}

$rg = New-AzResourceGroup -Name "rg-onprem-ad" -Location "West Europe"

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

Restart-AzVM -ResourceGroupName $rg.ResourceGroupName -Name $Deployment.Outputs.vmName.value -NoWait | Out-Null

$PublicIP = (Get-AzPublicIpAddress -ResourceGroupName $rg.ResourceGroupName -Name $Deployment.Outputs.publicIpName.value).IpAddress

Write-Host "Domain Controller is soon available at"
Write-Host "  RDP:   mstsc /V:$($PublicIP):3389"