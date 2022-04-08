param(
    [string] $subscriptionId,
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

Register-AzProviderFeature -FeatureName "EncryptionAtHost" -ProviderNamespace "Microsoft.Compute"
Register-AzProviderFeature -FeatureName "AKS-AzureDefender" -ProviderNamespace "microsoft.ContainerService"

Write-Output "Waiting for features to be registered..."
while (($statusEncryptionAtHost -eq "NotRegistered") -or ($statusAksAzureDefender -eq "NotRegistered")) {
    $statusEncryptionAtHost = Get-AzProviderFeature -FeatureName "EncryptionAtHost" -ProviderNamespace "Microsoft.Compute"  | Select-Object -ExpandProperty RegistrationState
    $statusAksAzureDefender = Get-AzProviderFeature -FeatureName "AKS-AzureDefender" -ProviderNamespace "microsoft.ContainerService"  | Select-Object -ExpandProperty RegistrationState
    Start-Sleep -s 15
}
Write-Output "Features successfully registered!"
Write-Output "Refreshing the registration of the Microsoft.Compute and microsoft.ContainerService"

Register-AzResourceProvider -ProviderNamespace "Microsoft.Compute"
Register-AzResourceProvider -ProviderNamespace "microsoft.ContainerService"