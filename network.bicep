// Azure region where the virtual network is created.
param location string
// Name assigned to the virtual network resource.
param vnetName string
// CIDR block reserved for the entire virtual network.
param addressPrefix string
// Name assigned to the subnet nested in the virtual network.
param subnetName string
// CIDR block allocated to the subnet; must fit inside addressPrefix.
param subnetPrefix string

// Create a virtual network with one subnet.
resource vnet 'Microsoft.Network/virtualNetworks@2026-03-01' = {
  name: vnetName
  location: location
  properties: {
    // Define the overall address space available to this virtual network.
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    // Create the subnet used by the compute module.
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
        }
      }
    ]
  }
}

// Return the fully qualified subnet resource ID. main.bicep passes this output as
// compute.bicep's subnetId parameter, which connects the NIC to this subnet.
output subnetId string = resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, subnetName)
