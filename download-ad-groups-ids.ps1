param(
    [string] $subscriptionId,
    [string] $subscriptionPrefix,
    [string] $subscriptionType,
    [string] $location,
    [string] $kvName
)

Connect-AzAccount -Identity
$principalSecret = Get-AzKeyVaultSecret -VaultName $kvName -Name "container-mgmt-principal-secret" -AsPlainText
$servicePrincipal = Get-AzKeyVaultSecret -VaultName $kvName -Name "container-mgmt-principal-client-id" -AsPlainText
$principalTenant = Get-AzKeyVaultSecret -VaultName $kvName -Name "container-mgmt-principal-tenant-id" -AsPlainText


$readerGroupName="${subscriptionType}-${location}-az-${subscriptionPrefix}-reader"
$writerGroupName="${subscriptionType}-${location}-az-${subscriptionPrefix}-writer"
$poweruserGroupName="${subscriptionType}-${location}-az-${subscriptionPrefix}-poweruser"

$tokenData = Invoke-WebRequest "https://login.microsoftonline.com/$principalTenant/oauth2/v2.0/token" -Headers @{"Content-Type" = "application/x-www-form-urlencoded"} -Method POST -Body "client_id=$servicePrincipal&scope=https%3A%2F%2Fgraph.microsoft.com%2F.default&client_secret=$principalSecret&grant_type=client_credentials" 
$accessToken = ($tokenData | ConvertFrom-Json).access_token
$DeploymentScriptOutputs = @{}

Write-Output "Read reader_group_data"
$readerGroupData = Invoke-WebRequest "https://graph.microsoft.com/v1.0/groups?`$search=%22displayName:$readerGroupName%22" -Headers @{"Content-Type" = "application/x-www-form-urlencoded"; "Authorization" = "Bearer $accessToken"; "ConsistencyLevel" = "eventual"} -Method GET
$readerGroupId = ($readerGroupData | ConvertFrom-Json).value[0].id
$DeploymentScriptOutputs['readerGroupId'] = $readerGroupId

Write-Output "Read writer_group_data"
$writerGroupData = Invoke-WebRequest "https://graph.microsoft.com/v1.0/groups?`$search=%22displayName:$writerGroupName%22" -Headers @{"Content-Type" = "application/x-www-form-urlencoded"; "Authorization" = "Bearer $accessToken"; "ConsistencyLevel" = "eventual"} -Method GET
$writerGroupId = ($writerGroupData | ConvertFrom-Json).value[0].id
$DeploymentScriptOutputs['writerGroupId'] = $writerGroupId

Write-Output "Read poweruser_group_data"
$poweruserGroupData = Invoke-WebRequest "https://graph.microsoft.com/v1.0/groups?`$search=%22displayName:$poweruserGroupName%22" -Headers @{"Content-Type" = "application/x-www-form-urlencoded"; "Authorization" = "Bearer $accessToken"; "ConsistencyLevel" = "eventual"} -Method GET
$poweruserGroupId = ($poweruserGroupData | ConvertFrom-Json).value[0].id
$DeploymentScriptOutputs['poweruserGroupId'] = $poweruserGroupId