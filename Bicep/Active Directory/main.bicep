@description('Resource Group to deploy resource in')
param location string = resourceGroup().location

@description('UserName')
@minLength(2)
@maxLength(28)
param onpremAdAdminUsername string

@description('Password')
@secure()
@minLength(12)
@maxLength(72)
param onpremAdAdminPassword string

@description('Allowed IP for RDP')
@minLength(7)
@maxLength(16)
param nsgAllowedIP string

@description('Domain Name')
@minLength(3)
@maxLength(128)
param onpremAdDomainName string = 'demo.local'

@description('Domain NetbiosName')
@minLength(3)
@maxLength(16)
param onpremAdDomainNetbiosName string = 'DEMO'


@description('Size of VM')
param vmSize string = 'Standard_B4ms'


var virtualMachineName = 'dc01'
var ResourceNamingSuffix = 'onpremad-test'
var storageAccountResourceName = '${virtualMachineName}st1'
var PublicIPResourceName = 'pip-${ResourceNamingSuffix}'
var NetworkSecurityGroupResourceName = 'nsg-${ResourceNamingSuffix}'
var virtualNetworkResourceName = 'vnet-${ResourceNamingSuffix}'
var virtualMachineResourceName = 'vm-${virtualMachineName}-${ResourceNamingSuffix}'
var nicResourceName = 'nic-${virtualMachineName}-${ResourceNamingSuffix}'
var vmPublisher = 'MicrosoftWindowsServer'
var vmOffer = 'WindowsServer'
var vmSku = '2022-datacenter-azure-edition'
var vmVersion = 'latest'
var addressPrefix = '10.0.0.0/16'
var subnetName = 'Subnet'
var subnetPrefix = '10.0.0.0/24'
var subnetReference = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkResourceName, subnetName)


resource StorageAccountResource 'Microsoft.Storage/storageAccounts@2021-01-01' = {
  name: storageAccountResourceName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource PublicIPResource 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
  name: PublicIPResourceName
  location: location
  properties: {
    publicIPAllocationMethod: 'Dynamic'
  }
}

resource NetworkSecurityGroupResource 'Microsoft.Network/networkSecurityGroups@2020-05-01' = {
  name: NetworkSecurityGroupResourceName
  location: location
  properties: {
    securityRules: [
      {
        name: 'DC-allow-rdp'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourceAddressPrefix: nsgAllowedIP
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }


    ]
  }
}

resource virtualNetworkResouce 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: virtualNetworkResourceName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: NetworkSecurityGroupResource.id
          }
        }
      }
    ]
  }
}

resource nicResource 'Microsoft.Network/networkInterfaces@2020-05-01' = {
  name: nicResourceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: PublicIPResource.id
          }
          subnet: {
            id: subnetReference
          }
        }
      }
    ]
  }
  dependsOn: [
    virtualNetworkResouce
  ]
}

resource virtualMachineResource 'Microsoft.Compute/virtualMachines@2020-06-01' = {
  name: virtualMachineResourceName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: virtualMachineName
      adminUsername: onpremAdAdminUsername
      adminPassword: onpremAdAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: vmPublisher
        offer: vmOffer
        sku: vmSku
        version: vmVersion
      }
      osDisk: {
        name: '${virtualMachineResourceName}-osdisk'
        caching: 'ReadWrite'
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicResource.id
        }
      ]
    }
  }
  dependsOn: [
    StorageAccountResource
  ]
}

resource virtualMachineResourceCreateDomain 'Microsoft.Compute/virtualMachines/extensions@2018-06-01' = {
  name: '${virtualMachineResourceName}/CreateDomain'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      fileUris: [
        'https://raw.githubusercontent.com/rirofal/Snippets/main/Bicep/Active%20Directory/createdomain.ps1'
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File createdomain.ps1 -SafeModePassword ${onpremAdAdminPassword} -DomainName ${onpremAdDomainName} -DomainNetbiosName ${onpremAdDomainNetbiosName}'
    }
  }
  dependsOn: [
    virtualMachineResource
  ]
}

resource virtualMachineResourceCreateADStructure 'Microsoft.Compute/virtualMachines/extensions@2018-06-01' = {
  name: '${virtualMachineResourceName}/CreateADStructure'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      fileUris: [
        'https://raw.githubusercontent.com/rirofal/Snippets/main/Bicep/Active%20Directory/createAdStructure.ps1'
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File createAdStructure.ps1'
    }
  }
  dependsOn: [
    virtualMachineResourceCreateDomain
  ]
}

output VMName string = virtualMachineResourceName
output PublicIpName string = PublicIPResourceName
