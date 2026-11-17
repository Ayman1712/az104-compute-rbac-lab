// ENTRY POINT AND DEPLOYMENT FLOW
// Deploy this file at subscription scope, for example with `az deployment sub create`
// using `main.bicep` and `dev.parameters.json`. The parameter file overrides values
// declared below (currently environment, location, and vmSize); adminPassword is
// intentionally omitted there because it is secure and must be supplied separately.
//
// This file creates two resource groups, then calls reusable modules inside them:
//   rgA: security.bicep creates the ADE-ready Key Vault; network.bicep creates VNet A;
//        compute.bicep creates VM A and its NIC using networkA's subnetId output.
//   rgB: network.bicep creates VNet B; compute.bicep creates VM B using networkB's
//        subnetId output.
// Module parameters flow from this parent into each module's `param` declarations.
// A child module's `output` can flow back to this file as `module.outputs.name`.
// References such as `networkA.outputs.subnetId` create deployment dependencies, so
// the relevant subnet is ready before its VM module is deployed. Independent modules
// can run in parallel. ADE itself is enabled later with a cmdlet, not by these modules.
// JSON parameter files do not support comments; use these notes to understand dev.parameters.json.
// Deploy the resource groups and modules from subscription scope.
targetScope = 'subscription'

// Suffix resource names with the deployment environment, such as dev or test.
// Required input: supplied by the deployment parameter file or the deployment command.
param environment string
// Azure region used for the resource groups and their resources.
// Required input: supplied by the deployment parameter file or the deployment command.
param location string
// Optional input: can be overridden by the deployment parameter file or command.
// The default is globally unique by subscription and environment.
param vaultName string = 'kv-az104-${uniqueString(subscription().id, environment)}'
// Linux account created on each virtual machine.
// Optional input: uses this default unless overridden.
param adminUsername string = 'azureuser'
// Shared VM hardware size passed to both compute modules.
// Match the VM SKU selected in dev.parameters.json.
// Azure still requires sufficient quota and regional capacity for the chosen SKU.
param vmSize string = 'Standard_D2s_v3'
// Keep the administrator password out of deployment logs and parameter display.
// Required secure input: not stored in dev.parameters.json; supply through a secure deployment mechanism.
@secure()
param adminPassword string

// Resource group for the first network and VM.
// These resources are declared in the subscription deployment and become scopes for modules below.
resource rgA 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: 'rg-lab-a-${environment}'
  location: location
}

// Resource group for the second network and VM.
resource rgB 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: 'rg-lab-b-${environment}'
  location: location
}

// Create the ADE-enabled Key Vault in the first resource group.
// `./security.bicep` is a child template; `scope` makes its resources belong to rgA.
// The module's outputs are intentionally unused: the ADE cmdlet will look up the vault.
module security './security.bicep' = {
  // Keep the nested deployment name unique and below Azure's 24-character limit.
  name: 'security-${uniqueString(rgA.id)}'
  scope: rgA
  params: {
    location: location
    vaultName: vaultName
  }
}

// Create the first virtual network and expose its subnet ID to the VM module.
// The network module receives its configuration as named parameter values.
module networkA './network.bicep' = {
  name: 'deploy-vnet-a-${environment}'
  scope: rgA
  params: {
    location: location
    // Address space and subnet reserved for the first lab network.
    vnetName: 'vnet-a-${environment}'
    addressPrefix: '10.1.0.0/16'
    subnetName: 'snet-a-${environment}'
    subnetPrefix: '10.1.1.0/24'
  }
}

// Create an isolated second virtual network in the second resource group.
// This is another instance of the same reusable network module with different inputs.
module networkB './network.bicep' = {
  name: 'deploy-vnet-b-${environment}'
  scope: rgB
  params: {
    location: location
    // Distinct address range prevents overlap with the first lab network.
    vnetName: 'vnet-b-${environment}'
    addressPrefix: '10.2.0.0/16'
    subnetName: 'snet-b-${environment}'
    subnetPrefix: '10.2.1.0/24'
  }
}

// Deploy the first VM into the subnet created by networkA.
// The subnet output reference creates an implicit dependency on networkA.
module vmA './compute.bicep' = {
  name: 'deploy-vm-a-${environment}'
  scope: rgA
  params: {
    location: location
    vmName: 'vm-a-${environment}'
    nicName: 'nic-a-${environment}'
    // Reuse the shared VM size, credentials, and network output.
    vmSize: vmSize
    subnetId: networkA.outputs.subnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// Deploy the second VM into the subnet created by networkB.
// The subnet output reference creates an implicit dependency on networkB.
module vmB './compute.bicep' = {
  name: 'deploy-vm-b-${environment}'
  scope: rgB
  params: {
    location: location
    vmName: 'vm-b-${environment}'
    nicName: 'nic-b-${environment}'
    // Keep VM configuration consistent while using the second network.
    vmSize: vmSize
    subnetId: networkB.outputs.subnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
  }
}

// Deploy the custom RBAC role at the subscription scope
module customRole './customRole.bicep' = {
  name: 'deploy-custom-role-${environment}'
  params: {
    roleName: 'Compute Admin'
    roleDescription: 'Can create and manage VMs, NICs, and attach to subnets within the assigned scope.'
  }
}