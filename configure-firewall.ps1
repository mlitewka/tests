param(
    [string] $aksName,
    [string] $subnetAddressPrefix,
    [string] $kvName,
    [string] $firewallPolicyName,
    [string] $firewallPolicySubscriptionId,
    [string] $firewallPolicyResourceGroup
)

Connect-AzAccount -Identity
$principalSecret = Get-AzKeyVaultSecret -VaultName $kvName -Name "container-mgmt-principal-secret" -AsPlainText
$servicePrincipal = Get-AzKeyVaultSecret -VaultName $kvName -Name "container-mgmt-principal-client-id" -AsPlainText
$principalTenant = Get-AzKeyVaultSecret -VaultName $kvName -Name "container-mgmt-principal-tenant-id" -AsPlainText

$SecureStringPwd = $principalSecret | ConvertTo-SecureString -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $servicePrincipal, $SecureStringPwd
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $principalTenant
Set-AzContext -Subscription $firewallPolicySubscriptionId

$networkRuleCollectionGroup = "DefaultNetworkRuleCollectionGroup"
$networkRuleCollection = "aksfwnetrules"
$appRuleCollectionGroup = "DefaultApplicationRuleCollectionGroup"
$appRuleCollection = "aksfwapprules"

$psFirewallPolicy = Get-AzFirewallPolicy -Name $firewallPolicyName -ResourceGroupName $firewallPolicyResourceGroup

$newNetworkRule = New-AzFirewallPolicyNetworkRule `
                    -Name "time-${aksName}" `
                    -SourceAddress $subnetAddressPrefix `
                    -Protocol UDP `
                    -DestinationFqdn "ntp.ubuntu.com" `
                    -DestinationPort 123

$psNetworkRuleCollectionGroup = Get-AzFirewallPolicyRuleCollectionGroup -Name $networkRuleCollectionGroup -ResourceGroupName $firewallPolicyResourceGroup -AzureFirewallPolicyName $firewallPolicyName 2> $null
$getNetworkRuleCollection = $psNetworkRuleCollectionGroup.Properties.RuleCollection | Where-Object {$_.Name -match $networkRuleCollection}

if ($getNetworkRuleCollection) {
    Write-Output "Rule collection $networkRuleCollection already exists. Adding new rule."
    $getNetworkRuleCollection.RuleS.Add($newNetworkRule)
    Set-AzFirewallPolicyRuleCollectionGroup `
        -Name $networkRuleCollectionGroup `
        -FirewallPolicyObject $psFirewallPolicy `
        -Priority 200 `
        -RuleCollection $psNetworkRuleCollectionGroup.Properties.RuleCollection
} else {
    Write-Output "Rule collection $networkRuleCollection not found."
    $newRuleCollectionConfig = New-AzFirewallPolicyFilterRuleCollection `
                                 -Name $networkRuleCollection `
                                 -Priority 200 `
                                 -Rule $newNetworkRule `
                                 -ActionType Allow
    $newRuleCollection = $psNetworkRuleCollectionGroup.Properties.RuleCollection.Add($newRuleCollectionConfig)
    Set-AzFirewallPolicyRuleCollectionGroup `
        -Name $networkRuleCollectionGroup `
        -FirewallPolicyObject $psFirewallPolicy `
        -Priority 200 `
        -RuleCollection $psNetworkRuleCollectionGroup.Properties.RuleCollection
}

$newApplicationRule1 = New-AzFirewallPolicyApplicationRule `
                        -Name "aksrepos-${aksName}" `
                        -SourceAddress $subnetAddressPrefix `
                        -FqdnTag "AzureKubernetesService"
$newApplicationRule2 = New-AzFirewallPolicyApplicationRule `
                        -Name "toolsrepos-${aksName}" `
                        -SourceAddress $subnetAddressPrefix `
                        -Protocol "http:80","https:443" `
                        -TargetFqdn "auth.docker.io", "registry-1.docker.io", "production.cloudflare.docker.com", "quay.io", "*.quay.io", "k8s.gcr.io", "storage.googleapis.com"

$psAppRuleCollectionGroup = Get-AzFirewallPolicyRuleCollectionGroup -Name $appRuleCollectionGroup -ResourceGroupName $firewallPolicyResourceGroup -AzureFirewallPolicyName $firewallPolicyName 2> $null
$getAppRuleCollection = $psAppRuleCollectionGroup.Properties.RuleCollection | Where-Object {$_.Name -match $appRuleCollection}

if ($getAppRuleCollection) {
    Write-Output "Rule collection $appRuleCollection already exists. Adding new rule."
    $getAppRuleCollection.RuleS.Add($newApplicationRule1)
    $getAppRuleCollection.RuleS.Add($newApplicationRule2)
    Set-AzFirewallPolicyRuleCollectionGroup `
        -Name $appRuleCollectionGroup `
        -FirewallPolicyObject $psFirewallPolicy `
        -Priority 300 `
        -RuleCollection $psAppRuleCollectionGroup.Properties.RuleCollection
} else {
    Write-Output "Rule collection $appRuleCollection not found."
    $newRuleCollectionConfig = New-AzFirewallPolicyFilterRuleCollection `
                                 -Name $appRuleCollection `
                                 -Priority 100 `
                                 -Rule $newApplicationRule1,$newApplicationRule2 `
                                 -ActionType Allow
    $newRuleCollection = $psAppRuleCollectionGroup.Properties.RuleCollection.Add($newRuleCollectionConfig)
    Set-AzFirewallPolicyRuleCollectionGroup `
        -Name $appRuleCollectionGroup `
        -FirewallPolicyObject $psFirewallPolicy `
        -Priority 300 `
        -RuleCollection $psAppRuleCollectionGroup.Properties.RuleCollection
}