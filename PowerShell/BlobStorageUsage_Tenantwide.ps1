#Set Tenant ID and Subscription ID
$tenantId = "xxxxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx"
$subscriptionId = "xxxxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxx"

# Requires: Az.Accounts, Az.Storage modules
$moduleName = "Az.Accounts"
if (!(Get-Module -ListAvailable -Name $moduleName)) {Install-Module -NameA $moduleName -Force}

$moduleName = "Az.Storage"
if (!(Get-Module -ListAvailable -Name $moduleName)) {Install-Module -Name $moduleName -Force}

# Login if not already authenticated
if (-not (Get-AzContext)) {
    connect-AzAccount -tenant $tenantId -Subscription $subscriptionId
}

# Get all subscriptions in the tenant
$subscriptions = Get-AzSubscription -TenantId $tenantId  | Select-Object -ExpandProperty Name | where { $_ -notlike "*Visual*" -and $_ -notlike "*MSDN*" -and $_ -notlike "*Pay-As-You-Go*" }

$result = @()

foreach ($sub in $subscriptions) {
    Set-AzContext -Subscription $sub | Out-Null

    $storageAccounts = Get-AzStorageAccount

    foreach ($sa in $storageAccounts) {
    $resourceGroup = $sa.ResourceGroupName
    $accountName = $sa.StorageAccountName
    $appIdTag = $sa.Tags["AppID"]

    # Build the Blob service resource ID
    $blobResourceId = "$($sa.Id)/blobServices/default"

    # Get the UsedCapacity metric for the Blob service
    $metric = Get-AzMetric -ResourceId $blobResourceId -MetricName "BlobCapacity"

    $BlobCapacityBytes = $metric.Data.Average

    $result += [PSCustomObject]@{
        Subscription          = $sub
        StorageAccount        = $accountName
        ResourceGroup         = $resourceGroup
        Location              = $sa.Location  
        AppID                 = $appIdTag                # Add AppID tag here
        BlobCapacityBytes     = $BlobCapacityBytes 
        BlobCapacityGigaBytes = [math]::Round($BlobCapacityBytes / 1GB, 2)
        BlobCapacityTeraBytes = [math]::Round($BlobCapacityBytes / 1TB, 4)
        BlobCapacityPetaBytes = [math]::Round($BlobCapacityBytes / 1PB, 6)
        TimeStamp             = $metric.Data.TimeStamp
    }
}

}
$result | Export-Csv -Path "$env:USERPROFILE\Downloads\StorageAccountUsage.csv" -NoTypeInformation
