targetScope = 'subscription'

param roleName string = 'Compute Admin'

param roleDescription string = 'Can create and manage VMs, NICs, and attach to subnets within the assigned scope.'

resource customRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(subscription().id, roleName)
  properties: {
    roleName: roleName
    description: roleDescription
    type: 'CustomRole'
    assignableScopes: [
      subscription().id
    ]
    permissions: [
      {
        actions: [
          'Microsoft.Resources/subscriptions/resourceGroups/read'
          'Microsoft.Compute/virtualMachines/read'
          'Microsoft.Compute/virtualMachines/write'
          'Microsoft.Network/networkInterfaces/read'
          'Microsoft.Network/networkInterfaces/write'
          'Microsoft.Network/virtualNetworks/subnets/join/action'
        ]
        notActions: []
      }
    ]
  }
}

output roleId string = customRole.id
