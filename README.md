az104-compute-rbac-lab

Hands-on AZ-104 study project: deploying VMs across resource groups with custom RBAC, disk encryption, and cost controls — built entirely in Bicep, with PowerShell used for diagnostics, role management, and encryption.

Problem

How do you secure virtual machines while controlling who can manage them and what they cost? This lab builds a small but realistic environment to practice three AZ-104 domains at once: compute deployment, identity and access (custom RBAC), and cost management — using modular, reusable Infrastructure as Code rather than one-off portal clicks.

Architecture

Two isolated environments, each in its own resource group, built from the same reusable Bicep modules called with different parameters.

Azure Subscription
assignable at
assignable at
rg-lab-b-dev (australiaeast)
vnet-b-dev10.2.0.0/16
snet-b-dev10.2.1.0/24
nic-b-dev
vm-b-dev(Linux)
Custom Role:Compute Admin(RG read, VM read/write,NIC read/write, subnet join)
rg-lab-a-dev (australiaeast)
vnet-a-dev10.1.0.0/16
snet-a-dev10.1.1.0/24
nic-a-dev
vm-a-dev(Linux)
kv-az104-<unique>Key Vault(enabledForDiskEncryption)
Two resource groups, one per "environment slice," each with its own non-overlapping /16 VNet and /24 subnet — isolated by default, no peering.
One reusable network.bicep module, called twice with different scopes and address ranges.
One reusable compute.bicep module (NIC + Linux VM), called twice, no public IP or Bastion.
One security.bicep module provisioning a Key Vault configured for Azure Disk Encryption (enabledForDiskEncryption: true).
One custom RBAC role, Compute Admin, designed from first principles (see Lessons Learned).
main.bicep orchestrates all of the above from subscription scope, creating the resource groups and wiring module outputs (e.g. subnet IDs) into dependent modules.
Repository structure
az104-compute-rbac-lab/
├── README.md
├── main.bicep              # Subscription-scope orchestrator
├── network.bicep           # Reusable module: VNet + subnet
├── compute.bicep           # Reusable module: NIC + VM
├── security.bicep          # Key Vault, ADE-ready
├── customRole.bicep        # Custom RBAC role definition
├── dev.parameters.json     # Environment + location + VM size
└── scripts/
    └── rbac-notes.md        # PowerShell commands used to research and test the role
    
Setup instructions
Prerequisites
An Azure subscription
Bicep CLI and the Az PowerShell module (or use Azure Cloud Shell, which has both preinstalled)
VS Code with the Bicep extension (recommended for authoring)
Deploy
powershell
# Sign in and confirm the target subscription
Connect-AzAccount
Get-AzContext

# Preview the deployment (no resources are created)
$pw = Read-Host -AsSecureString -Prompt 'VM admin password'
New-AzSubscriptionDeployment `
  -Name 'lab-deploy' `
  -Location 'australiaeast' `
  -TemplateFile main.bicep `
  -TemplateParameterFile dev.parameters.json `
  -adminPassword $pw `
  -WhatIf

# Deploy
New-AzSubscriptionDeployment `
  -Name 'lab-deploy' `
  -Location 'australiaeast' `
  -TemplateFile main.bicep `
  -TemplateParameterFile dev.parameters.json `
  -adminPassword $pw
Deploy the custom role
powershell
New-AzSubscriptionDeployment `
  -Name 'lab-rbac' `
  -Location 'australiaeast' `
  -TemplateFile customRole.bicep
Verify
powershell
Get-AzResourceGroup | Select-Object ResourceGroupName, Location
Get-AzVirtualNetwork | Select-Object Name, ResourceGroupName
Get-AzRoleDefinition -Name 'Compute Admin' | Select-Object Name, Actions
Lessons learned
Custom roles vs. built-in roles

Rather than starting from a built-in role (like Contributor) and subtracting permissions with NotActions, this role was built as a minimal allow-list from scratch, using Get-AzProviderOperation to find the exact permission strings needed:

Microsoft.Resources/subscriptions/resourceGroups/read
Microsoft.Compute/virtualMachines/read
Microsoft.Compute/virtualMachines/write
Microsoft.Network/networkInterfaces/read
Microsoft.Network/networkInterfaces/write
Microsoft.Network/virtualNetworks/subnets/join/action

Delete was never granted, not explicitly excluded. Because RBAC is deny-by-default, simply omitting virtualMachines/delete and resourceGroups/delete from Actions is sufficient — there's no need for a NotActions entry when the permission was never granted in the first place. NotActions is really for carving exceptions out of a broad grant (like a wildcard), not for blocking a specific action in an otherwise narrow list.

The easy-to-miss permission: creating a VM's NIC isn't enough on its own — attaching that NIC to a subnet requires its own distinct action, Microsoft.Network/virtualNetworks/subnets/join/action. This is a deliberate Azure safeguard: being able to create network interfaces doesn't automatically mean you can plug into any subnet you can see.

assignableScopes was deliberately kept at subscription scope rather than narrowed to the two resource groups. In practice, a role's assignableScopes controls where the role is eligible to be assigned, not where it's actually assigned — the real narrowing happens at assignment time (New-AzRoleAssignment -Scope ...). Keeping it broad mirrors how enterprise platform teams typically define reusable roles once and assign them narrowly per environment, rather than redefining a role per resource group.

Cost alert quirks

Attempting to create a budget via New-AzConsumptionBudget (and separately, via the portal) returned:

Cost Management supports only Enterprise Agreement, Web direct and Microsoft Customer Agreement offer types.
Subscription ... is not associated with a valid offer type.

This is a hard platform limitation of free-trial subscriptions, not a syntax or tooling issue — confirmed via two independent paths (PowerShell and the Azure Portal) hitting the identical root cause. A budget can be fully defined as IaC (Microsoft.Consumption/budgets) for a subscription with a supported offer type, but cannot be created here. A related and genuinely useful finding: budgets only alert — they never stop spending. Actually capping spend requires an action group wired to automation, a separate mechanism entirely.

Compute quota on free-trial subscriptions

Six VM sizes across four families (Standard_B2as_v2, B2s_v2, B2ats_v2, B2ts_v2, B2pts_v2, B1s) were tested in australiaeast. Every paid family returned QuotaExceeded with Current Limit: 0, Current Usage: 0; the nominally free-tier B1s returned SkuNotAvailable (Capacity Restrictions) instead. Registering the Microsoft.Compute resource provider did not resolve this. The same pattern held across both PowerShell and the Azure Portal, across two regions (australiaeast, australiasoutheast). This points to the free-trial subscription having no standing compute capacity provisioned in this region at the time of testing — a subscription-level constraint, not a template or tooling defect. Standard_D2s_v3 was the last candidate identified (via the portal's size picker) as potentially available; main.bicep and dev.parameters.json are written to deploy with any size via a single parameter.

Azure Disk Encryption (ADE)

ADE's memory requirements rule out the smallest burstable sizes: 2 GB minimum for data-volume-only encryption, 8 GB minimum for OS-volume encryption on a typical root filesystem. Because every size with ≥8 GB RAM fell outside the subscription's available quota (above), ADE itself was not deployed live. The Key Vault module (security.bicep), correctly configured with enabledForDiskEncryption: true, was deployed successfully as evidence of the prerequisite work. ADE is also scheduled for retirement by Microsoft (September 2028), which now recommends encryption at host for new VMs — a stronger real-world argument for using that mechanism going forward, independent of this subscription's limitations.

Bicep tooling notes
API versions lag the type library: a locally installed Bicep CLI can accept a valid Azure API version syntactically (no error) but still warn BCP081: does not have types available if that version postdates the CLI's bundled type definitions. Get-AzResourceProvider is the source of truth for which versions actually exist; the editor/CLI's autocomplete tells you which ones it can validate. The two aren't always the same list.
Filename case sensitivity: macOS treats filenames case-insensitively; Cloud Shell (Linux) does not. A module referenced as ./network.bicep will fail to resolve if the uploaded file is actually Network.bicep, even though both looked identical locally. Standardizing on lowercase filenames throughout avoided this entirely.
Deployment names are permanent per name/location pair. Reusing a -Name with a different -Location on a subscription-scope deployment fails outright; each test run needs a fresh name if the location changes.
Known limitations
Deliverable	Status	Reason
2 VMs in different resource groups	Written, validated via what-if, not live-deployed	Zero compute quota / capacity restrictions across every tested VM family on this free-trial subscription (see above)
Azure Disk Encryption	Not live-deployed; Key Vault prerequisite deployed	Depends on a VM size (≥8 GB RAM) that was unavailable (see above)
Custom RBAC role	Complete — deployed and verified in the portal	—
$10 cost budget alert	Not possible on this subscription	Free-trial offer type is unsupported by Azure Cost Management (see above)
Screenshots
Resource groups and deployment history (portal)
Deployed VNets and subnets (Get-AzVirtualNetwork + portal)
Custom role permissions, assignable scopes, and JSON definition (portal)
QuotaExceeded / Cost Management offer-type errors, as evidence of the documented limitations
