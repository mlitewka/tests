param(
    [string] $aksName,
    [string] $aksResourceGroup,
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

$aksClusterObject = Get-AzAksCluster -Name $aksName -ResourceGroupName $aksResourceGroup

# kube-bench
$aksClusterObject | Invoke-AzAksRunCommand `
    -CommandContextAttachment "./kube-bench-scan-job.yaml" `
    -Command @"
    chmod -R +r .
    kubectl create namespace sec-kube-bench-system
    kubectl apply -f kube-bench-scan-job.yaml
    kubectl wait --for=condition=complete job/kube-bench -n sec-kube-bench-system --timeout 120s
"@ `
    -Force

# kube-hunter
$aksClusterObject | Invoke-AzAksRunCommand `
    -CommandContextAttachment "./kube-hunter-scan-job.yaml" `
    -Command @"
    chmod -R +r .
    kubectl create namespace sec-kube-hunter-system
    kubectl apply -f kube-hunter-scan-job.yaml -n sec-kube-hunter-system
    kubectl wait --for=condition=complete job/kube-hunter -n sec-kube-hunter-system --timeout 120s
"@ `
    -Force

