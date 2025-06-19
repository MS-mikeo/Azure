# Set variable for storage account ID for FinOps Hub, FinOps Hub Version, and number of months for backfill data
$StorageAccountId="/subscriptions/xxxx-xxxx-xxxxxxxx-xxxxxxxxx/resourceGroups/rg-xxxxxxx/providers/Microsoft.Storage/storageAccounts/finopshubv0sxxxxxxxxxxxxxxxxx"
$FinOpsHubVersion="V011"
$BackfillMonths="10"
$TenantID=xxxx-xxxx-xxxxxxxx-xxxxxxxxx
$SubscriptionID=xxxx-xxxx-xxxxxxxx-xxxxxxxxx

# Checking for modules and installing
$moduleName = "Az.Accounts"
if (!(Get-Module -ListAvailable -Name $moduleName)) {
    Install-Module -Name $moduleName -Force
}
$moduleName = "Az.Resources"
if (!(Get-Module -ListAvailable -Name $moduleName)) {
    Install-Module -Name $moduleName -Force
}
$moduleName = "FinOpsToolkit"
if (!(Get-Module -ListAvailable -Name $moduleName)) {
    Install-Module -Name $moduleName -Force
}

#Importing modules
Import-Module -Name Az.Accounts
Import-Module -Name Az.Resources
Import-Module -Name FinOpsToolkit

#Connecting to Azure
connect-azaccount -tenantID $TenantID -Subscription $SubscriptionID

# Getting list of subscriptions to loop through for exports
$subscriptions=get-azsubscription
foreach ($subscription in $subscriptions) 
{
$Scope= "/subscriptions/" + $subscription.Id
$ExportName="Focus-" + $FinOpsHubVersion

#Configuring daily month to date exports for each subscription and backfill for months entered in variables
New-FinopsCostExport -Name $ExportName `
    -Scope $Scope `
    -StorageAccountId $StorageAccountId `
    -DataSet "FocusCost" `
    -DataSetVersion "1.0r2" `
    -StorageContainer "msexports" `
    -Backfill $BackfillMonths `
    -Execute 
}
