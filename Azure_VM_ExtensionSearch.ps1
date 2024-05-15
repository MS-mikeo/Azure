$moduleName = "Az.Accounts"
if (!(Get-Module -ListAvailable -Name $moduleName)) {
    Install-Module -Name $moduleName -Force
}

$moduleName = "Az.Resources"
if (!(Get-Module -ListAvailable -Name $moduleName)) {
    Install-Module -Name $moduleName -Force
}

$moduleName = "Az.Compute"
if (!(Get-Module -ListAvailable -Name $moduleName)) {
    Install-Module -Name $moduleName -Force
}

Import-module Az.Accounts
Import-module Az.Resources
Import-module Az.Compute

Connect-AzAccount

$subscriptions=get-azsubscription

# Create an array to store the extension data
$extensionData = @()  

foreach ($subscription in $subscriptions) {
set-azcontext -subscription $subscription.Name | Out-Null

$vms = Get-AzVM

# Loop through each virtual machine and looks for Qualys extension
foreach ($vm in $vms) {
    $vmName = $vm.Name
    $resourceGroup = $vm.ResourceGroupName
    $extensions = Get-AzVMExtension -ResourceGroupName $resourceGroup -VMName $vmName | where {$_.Publisher -contains 'Qualys'}
    foreach ($extension in $extensions) {
        $extensionData += [PSCustomObject]@{
            VirtualMachine = $vmName
            Subscription = $subscription.Name
            ResourceGroup = $resourceGroup
            ExtensionName = $extension.Name
            ExtensionType = $extension.ExtensionType
            Publisher = $extension.Publisher
            Version = $extension.Version
            ProvisioningState = $extension.ProvisioningState
        }
    }
}
}

# Display the extension data in a table
$extensionData | Format-Table -AutoSize
