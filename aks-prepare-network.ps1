param(
    [string] $subscriptionId,
    [string] $routeTableId,
    [string] $vNetResourceGroupName,
    [string] $virtualNetworkName,
    [string] $workloadSubnetName,
    [string] $subnetAddressPrefix,
    [string] $nsgName,
    [string] $kvName
)

Connect-AzAccount -Identity
$principalSecret = Get-AzKeyVaultSecret -VaultName $kvName -Name "container-mgmt-principal-secret" -AsPlainText
$servicePrincipal = Get-AzKeyVaultSecret -VaultName $kvName -Name "container-mgmt-principal-client-id" -AsPlainText
$principalTenant = Get-AzKeyVaultSecret -VaultName $kvName -Name "container-mgmt-principal-tenant-id" -AsPlainText

$SecureStringPwd = $principalSecret | ConvertTo-SecureString -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $servicePrincipal, $SecureStringPwd
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $principalTenant
Set-AzContext -Subscription $subscriptionId

$vnetObject = Get-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $vNetResourceGroupName
$subnetConfigObject = Get-AzVirtualNetworkSubnetConfig -Name $workloadSubnetName -VirtualNetwork $vnetObject

# Assign custom route table, disable PrivateEndpointNetworkPoliciesFlag, add service endpoint
$serviceEndPoints = New-Object 'System.Collections.Generic.List[String]'
$subnetConfigObject.ServiceEndpoints | ForEach-Object { $serviceEndPoints.Add($_.service) }

Set-AzVirtualNetworkSubnetConfig `
    -Name $workloadSubnetName `
    -VirtualNetwork $vnetObject `
    -AddressPrefix $subnetAddressPrefix `
    -RouteTableId $routeTableId `
    -PrivateEndpointNetworkPoliciesFlag "Disabled" `
    -ServiceEndpoint $serviceEndPoints.Add("Microsoft.KeyVault")
    
$vnetObject | Set-AzVirtualNetwork

# Add NSG rule
$nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $vNetResourceGroupName
$nsg | Add-AzNetworkSecurityRuleConfig `
        -Name 'AKSTraffic' `
        -Access Allow `
        -Protocol Tcp `
        -Direction Outbound `
        -Priority 900 `
        -SourceAddressPrefix $subnetAddressPrefix `
        -SourcePortRange * `
        -DestinationAddressPrefix * `
        -DestinationPortRange 443, 123
$nsg | Set-AzNetworkSecurityGroup