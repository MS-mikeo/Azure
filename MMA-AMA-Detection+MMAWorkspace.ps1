# Install the Azure PowerShell module if not already installed
# Install-Module -Name Az -AllowClobber -Scope CurrentUser

# Connect to Azure account
Connect-AzAccount

# Get the list of all subscriptions
$subscriptions = Get-AzSubscription 

# Create an array to store results
$results = @()

foreach ($subscription in $subscriptions) {
    Set-AzContext -SubscriptionId $subscription.Id

    # Get all resource groups
    $resourceGroups = Get-AzResourceGroup

    foreach ($rg in $resourceGroups) {
        # Get all VMs in the resource group
        $vms = Get-AzVM -ResourceGroupName $rg.ResourceGroupName

        foreach ($vm in $vms) {
            # Initialize variables
            $hasMMA = $false
            $hasAMA = $false
            $mmaWorkspaceId = $null

            # Get extensions for the VM
            $extensions = Get-AzVMExtension -ResourceGroupName $rg.ResourceGroupName -VMName $vm.Name

            foreach ($ext in $extensions) {
                if ($ext.ExtensionType -eq "MicrosoftMonitoringAgent") {
                    $hasMMA = $true
                    # Handle the case where PublicSettings might contain multiple JSON objects
                    $publicSettings = $ext.PublicSettings | ConvertFrom-Json
                    if ($publicSettings.workspaceId) {
                        $mmaWorkspaceId = $publicSettings.workspaceId
                    }
                } elseif ($ext.ExtensionType -eq "AzureMonitorWindowsAgent" -or $ext.ExtensionType -eq "AzureMonitorLinuxAgent") {
                    $hasAMA = $true
                }
            }

            # Create result object
            $result = [PSCustomObject]@{
                VMName                = $vm.Name
                ResourceGroup         = $rg.ResourceGroupName
                SubscriptionName      = $subscription.Name
                MicrosoftMonitoringAgentInstalled = $hasMMA
                AzureMonitorAgentInstalled = $hasAMA
                MMAWorkspaceId        = $mmaWorkspaceId
            }

            # Add to results array
            $results += $result
        }
    }
}

# Output results to a CSV file
$results | Export-Csv -Path "C:\AMA\VMMonitoringReport.csv" -NoTypeInformation
