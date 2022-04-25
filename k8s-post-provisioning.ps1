param(
    [string] $aksName,
    [string] $aksResourceGroup,
    [string] $aksNamespaces,
    [string] $subscriptionId,
    [string] $kvName,
    [string] $readerGroupId,
    [string] $writerGroupId,
    [string] $saPremiumName,
    [string] $saStandardName
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

# Create Namespaces
$aksNamespacesArray = ($aksNamespaces -replace '\s','').Split(';') | Select-Object -Unique
$aksNamespacesArray += "cicd"
foreach ($namespace in $aksNamespacesArray) {
    $aksClusterObject | Invoke-AzAksRunCommand -Command "kubectl create namespace ${namespace}" -Force
}

# Create Serviceaccount
$aksClusterObject | Invoke-AzAksRunCommand -Command "kubectl create serviceaccount sa-cicd --namespace cicd" -Force
$aksClusterObject | Invoke-AzAksRunCommand -CommandContextAttachment "./custom-roles.yaml" -Command "chmod -R +r . && kubectl apply -f custom-roles.yaml" -Force

# Create role and cluster role bindings
(Get-Content ./reader-clusterrolebinding.yaml).replace('azureGroupId', $readerGroupId) | Set-Content ./reader-clusterrolebinding.yaml
$aksClusterObject | Invoke-AzAksRunCommand -CommandContextAttachment "./reader-clusterrolebinding.yaml" -Command "chmod -R +r . && kubectl apply -f reader-clusterrolebinding.yaml" -Force

(Get-Content ./writer-clusterrolebinding.yaml).replace('azureGroupId', $writerGroupId) | Set-Content ./writer-clusterrolebinding.yaml
$aksClusterObject | Invoke-AzAksRunCommand -CommandContextAttachment "./writer-clusterrolebinding.yaml" -Command "chmod -R +r . && kubectl apply -f writer-clusterrolebinding.yaml" -Force

(Get-Content ./cicd-rolebinding.yaml).replace('azureGroupId', $writerGroupId) | Set-Content ./cicd-rolebinding.yaml
$aksClusterObject | Invoke-AzAksRunCommand -CommandContextAttachment "./cicd-rolebinding.yaml" -Command "chmod -R +r . && kubectl apply -f cicd-rolebinding.yaml" -Force

(Get-Content ./reader-rolebinding.yaml).replace('azureGroupId', $readerGroupId) | Set-Content ./reader-rolebinding.yaml
(Get-Content ./writer-rolebinding.yaml).replace('azureGroupId', $writerGroupId) | Set-Content ./writer-rolebinding.yaml
$aksNamespacesArray = ($aksNamespaces -replace '\s','').Split(';') | Select-Object -Unique
foreach ($namespace in $aksNamespacesArray) {
    (Get-Content ./reader-rolebinding.yaml).replace('namespace: app-ns', "namespace: $namespace") | Set-Content ./reader-rolebinding.yaml
    $aksClusterObject | Invoke-AzAksRunCommand -CommandContextAttachment "./reader-rolebinding.yaml" -Command "chmod -R +r . && kubectl apply -f reader-rolebinding.yaml" -Force
    
    (Get-Content ./writer-rolebinding.yaml).replace('namespace: app-ns', "namespace: $namespace") | Set-Content ./writer-rolebinding.yaml
    $aksClusterObject | Invoke-AzAksRunCommand -CommandContextAttachment "./writer-rolebinding.yaml" -Command "chmod -R +r . && kubectl apply -f writer-rolebinding.yaml" -Force
}

# Deploy storage classes
(Get-Content ./private-azurefile-csi.yaml).replace('<storageAccountName>', $saStandardName).replace('<resourceGroup>', $aksResourceGroup) | Set-Content ./private-azurefile-csi.yaml
$aksClusterObject | Invoke-AzAksRunCommand -CommandContextAttachment "./private-azurefile-csi.yaml" -Command "chmod -R +r . && kubectl apply -f private-azurefile-csi.yaml" -Force

(Get-Content ./private-premium-azurefile-csi.yaml).replace('<storageAccountName>', $saStandardName).replace('<resourceGroup>', $aksResourceGroup) | Set-Content ./private-premium-azurefile-csi.yaml
$aksClusterObject | Invoke-AzAksRunCommand -CommandContextAttachment "./private-premium-azurefile-csi.yaml" -Command "chmod -R +r . && kubectl apply -f private-premium-azurefile-csi.yaml" -Force

# ingress-nginx
$aksClusterObject | Invoke-AzAksRunCommand `
    -CommandContextAttachment "./custom-ingress-nginx-values.yaml" `
    -Command @"
    chmod -R +r .
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm install ingress-nginx -f custom-ingress-nginx-values.yaml ingress-nginx/ingress-nginx \
    --version 4.0.1 \
    --create-namespace \
    --namespace ingress-nginx \
    --set controller.replicaCount=3
"@ `
    -Force

# falcosecurity
$aksClusterObject | Invoke-AzAksRunCommand `
    -Command @"
    chmod -R +r .
    helm repo add falcosecurity https://falcosecurity.github.io/charts
    helm install falco falcosecurity/falco \
    --version 1.16.0 \
    --create-namespace \
    --namespace sec-falco-system
"@ `
    -Force

# gatekeeper
$aksClusterObject | Invoke-AzAksRunCommand `
    -Command @"
    chmod -R +r .
    helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
    helm install gatekeeper gatekeeper/gatekeeper \
    --namespace gatekeeper-system \
    --create-namespace \
    --version 3.7.0
"@ `
    -Force

# gatekeeper policy manager
Invoke-WebRequest -Uri "https://github.com/sighupio/gatekeeper-policy-manager/archive/refs/heads/main.zip" -OutFile ./main.zip
Expand-Archive -Path ./main.zip -DestinationPath .
$aksClusterObject | Invoke-AzAksRunCommand -CommandContextAttachment "./gatekeeper-policy-manager-main/" -Command "chmod -R +r . && kubectl apply -k ." -Force