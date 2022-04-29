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

$aksClusterObject | Invoke-AzAksRunCommand `
    -CommandContextAttachment "./gatekeeper-config.yaml" `
    -Command @"
    chmod -R +r .
    kubectl apply -f gatekeeper-config.yaml
"@ `
    -Force

# templates
$aksClusterObject | Invoke-AzAksRunCommand `
    -Command @"
    cd ~
    curl -L https://github.com/mlitewka/tests/archive/refs/heads/main.zip --output main.zip
    unzip -qq main.zip
    du -a | gawk '/template.*yaml/ {cmd="kubectl apply -f " `$2; print cmd; system(cmd)}'
"@ `
    -Force

# constraints
$aksClusterObject | Invoke-AzAksRunCommand `
    -Command @"
    cd ~
    curl -L https://github.com/mlitewka/tests/archive/refs/heads/main.zip --output main.zip
    unzip -qq main.zip
    du -a | gawk '/constraint.*yaml/ {cmd="kubectl apply -f " `$2; print cmd; system(cmd)}'
"@ `
    -Force