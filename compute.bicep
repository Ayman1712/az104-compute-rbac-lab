// Child-module inputs: values are passed by a `module` call in main.bicep.
// Azure region in which the NIC and VM are deployed.
param location string
// Azure resource name and guest operating-system computer name.
param vmName string
// NIC attached to this VM.
param nicName string
// VM hardware SKU passed from the parent deployment.
param vmSize string
// Subnet selected for the NIC's private IP configuration.
param subnetId string
// Linux administrator account settings.
param adminUsername string
// Treat the password as a secret parameter.
@secure()
param adminPassword string

// Create the network interface that connects the VM to its subnet.
// The VM's reference to nic.id below makes it depend on this resource.
resource nic 'Microsoft.Network/networkInterfaces@2026-03-01' = {
  name: nicName
  location: location
  properties: {
    // Configure the NIC's primary IP configuration.
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          // Attach this IP configuration to the subnet supplied by the network module.
          subnet: { id: subnetId }
          // Let Azure assign an available private address.
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// Create the Linux VM after the NIC is available.
// This module currently defines the VM only; ADE is enabled afterward with a cmdlet.
resource vm 'Microsoft.Compute/virtualMachines@2026-04-01' = {
  name: vmName
  location: location
  properties: {
    // Select the requested VM hardware size.
    hardwareProfile: {
      vmSize: vmSize
    }
    // Configure the guest operating system and local administrator.
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      // This image accepts password authentication for the configured account.
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }

    // Select the operating system image and boot disk configuration.
    storageProfile: {
      imageReference: {
        // Ubuntu Server 24.04 LTS image from Canonical.
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        // Create the OS disk from the selected image using standard locally redundant storage.
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    // Attach the NIC created above to the VM.
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}
