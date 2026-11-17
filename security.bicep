// Child-module inputs passed by the `security` module call in main.bicep.
// Region for the Key Vault; it must match the target resource group's location.
param location string
// Globally unique DNS name for the Key Vault.
param vaultName string

// Create a vault configured to store Azure Disk Encryption secrets.
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: vaultName
  location: location
  properties: {
    // Associate the vault with the current Microsoft Entra tenant.
    tenantId: tenant().tenantId
    // Use the standard Key Vault service tier.
    sku: {
      family: 'A'
      name: 'standard'
    }
    // No user or service-principal access policies are assigned by this template.
    accessPolicies: []
    // ADE does not require deployment or template deployment access.
    enabledForDeployment: false
    // Enable the Key Vault integration required by Azure Disk Encryption.
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: false
  }
}

// These outputs are available to the parent as `security.outputs.keyVaultId` and
// `security.outputs.keyVaultUri`. main.bicep does not consume them because ADE is
// enabled afterward with a cmdlet that looks up the vault.
output keyVaultId string = keyVault.id
// Expose the vault endpoint URL used by Key Vault clients.
output keyVaultUri string = keyVault.properties.vaultUri