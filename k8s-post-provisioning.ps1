param(
    [string] $aksName,
    [string] $aksResourceGroup,
    [string] $aksNamespaces,
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

# $aksClusterObject = Get-AzAksCluster -Name $aksName -ResourceGroupName $aksResourceGroup

# $aksNamespacesArray = ($aksNamespaces -replace '\s','').Split(',') | Select-Object -Unique
# $aksNamespacesArray += "cicd"
# foreach ($namespace in $aksNamespacesArray) {
#     $aksClusterObject | Invoke-AzAksRunCommand -Command "kubectl create namespace ${namespace}"
# }

# $aksClusterObject | Invoke-AzAksRunCommand -Command "kubectl create serviceaccount sa-cicd --namespace cicd"
# $aksClusterObject | Invoke-AzAksRunCommand -CommandContextAttachment ".\custom-roles.yaml" -Command "kubectl apply -f custom-roles.yaml"