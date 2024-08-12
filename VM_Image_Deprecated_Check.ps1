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


# Install Azure PowerShell module if not already installed
# Install-Module -Name Az -AllowClobber -Scope CurrentUser

$moduleName = "Az.Accounts"
if (!(Get-Module -ListAvailable -Name $moduleName)) {
    Install-Module -Name $moduleName -Force
}
$moduleName = "Az.Compute"
if (!(Get-Module -ListAvailable -Name $moduleName)) {
    Install-Module -Name $moduleName -Force
}

Import-module Az.Accounts

Import-module Az.Compute


# Connect to Azure account
Connect-AzAccount

# Get all subscriptions
$subscriptions = Get-AzSubscription

# Array to hold results
$results = @()

foreach ($subscription in $subscriptions) {
    # Set the current subscription context
    Set-AzContext -SubscriptionId $subscription.Id

    # Get all VMs in the current subscription
    $vms = Get-AzVM -Status | where-object { $_.StorageProfile.ImageReference.Publisher -ne $Null }

    foreach ($vm in $vms) {
        # Extract image reference details
        $imageReference = $vm.StorageProfile.ImageReference
        $imagePublisher = $imageReference.Publisher
        $imageOffer = $imageReference.Offer
        $imageSku = $imageReference.Sku
        $imageVersion = $imageReference.ExactVersion

        # Get the location (region) of the VM
        $location = $vm.Location

        # Initialize deprecation status
        $deprecationStatus = "Unknown"

        # Check the deprecation status of the marketplace image
        $imageInfo = Get-AzVMImage -Location $location -PublisherName $imagePublisher -Offer $imageOffer -Sku $imageSku -Version $imageVersion -errorvariable errormessage
        $deprecationStatus = $imageInfo.ImageDeprecationStatus.ImageState
	      if ($null -eq $deprecationStatus) {
        # Populate the variable with a new value if it's null
        $deprecationStatus = $errormessage 
        }


        # Create an object for the result
        $result = [PSCustomObject]@{
            SubscriptionId = $subscription.Id
            SubscriptionName = $subscription.Name
            VMName = $vm.Name
            ResourceGroup = $vm.ResourceGroupName
            Location = $location
            ImagePublisher = $imagePublisher
            ImageOffer = $imageOffer
            ImageSku = $imageSku
            ImageVersion = $imageVersion
            DeprecationStatus = $deprecationStatus
        }

        # Add result to the array
        $results += $result
    }
}

# Output the results
$results 
