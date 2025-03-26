# ===========================================================================================
#
# This sample script is not supported under any Microsoft standard support program or service. 
# The sample script is provided AS IS without warranty of any kind. Microsoft further disclaims 
# all implied warranties including, without limitation, any implied warranties of merchantability 
# or of fitness for a particular purpose. The entire risk arising out of the use or performance of 
# the sample scripts and documentation remains with you. In no event shall Microsoft, its authors, 
# or anyone else involved in the creation, production, or delivery of the scripts be liable for any 
# damages whatsoever (including, without limitation, damages for loss of business profits, business 
# interruption, loss of business information, or other pecuniary loss) arising out of the use of or 
# inability to use the sample scripts or documentation, even if Microsoft has been advised of the 
# possibility of such damages 
#
# ===========================================================================================


# Login to Azure (if not already logged in)
Connect-AzAccount

# Array to store empty storage accounts
$emptyStorageAccounts = @()

# Get all subscriptions that the logged-in account has access to
$subscriptions = Get-AzSubscription

foreach ($subscription in $subscriptions) {
    # Select the current subscription
    Set-AzContext -SubscriptionId $subscription.Id

    # Get all storage accounts in the current subscription
    $storageAccounts = Get-AzStorageAccount

    foreach ($storageAccount in $storageAccounts) {
        $storageAccountName = $storageAccount.StorageAccountName
        $resourceGroupName = $storageAccount.ResourceGroupName

        # Check if the storage account has no tables, queues, file shares, or blob containers
        $isEmpty = $true

        # Check for tables
        $tables = Get-AzStorageTable -Context $storageAccount.Context -ErrorAction SilentlyContinue
        if ($tables.Count -gt 0) {
            $isEmpty = $false
        }

        # Check for queues
        $queues = Get-AzStorageQueue -Context $storageAccount.Context -ErrorAction SilentlyContinue
        if ($queues.Count -gt 0) {
            $isEmpty = $false
        }

        # Check for file shares
        $fileShares = Get-AzStorageShare -Context $storageAccount.Context -ErrorAction SilentlyContinue
        if ($fileShares.Count -gt 0) {
            $isEmpty = $false
        }

        # Check for blob containers
        $blobContainers = Get-AzStorageContainer -Context $storageAccount.Context -ErrorAction SilentlyContinue
        if ($blobContainers.Count -gt 0) {
            $isEmpty = $false
        }

        # If the storage account is empty, add it to the array
        if ($isEmpty) {
            $emptyStorageAccountInfo = @{
                SubscriptionName = $subscription.Name
                ResourceGroupName = $resourceGroupName
                StorageAccountName = $storageAccountName
            }
            $emptyStorageAccounts += New-Object PSObject -Property $emptyStorageAccountInfo
        }
    }
}

$tables =""
$queues =""
$fileShares =""
$blobContainers =""


# Output the array of empty storage accounts
$emptyStorageAccounts
