# Install Azure PowerShell module if not already installed
# Install-Module -Name Az -AllowClobber -Scope CurrentUser

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
    $vms = Get-AzVM -Status

    foreach ($vm in $vms) {
        # Extract image reference details
        $imageReference = $vm.StorageProfile.ImageReference
        $imagePublisher = $imageReference.Publisher
        $imageOffer = $imageReference.Offer
        $imageSku = $imageReference.Sku
        $imageVersion = $imageReference.Version

        # Get the location (region) of the VM
        $location = $vm.Location

        # Initialize deprecation status
        $deprecationStatus = "Unknown"

        # Check the deprecation status of the marketplace image
        $imageInfo = Get-AzVMImage -Location $location -PublisherName $imagePublisher -Offer $imageOffer -Sku $imageSku -Version $imageVersion -errorvariable errormessage
        $deprecationStatus = $imageInfo.ImageDeprecationStatus
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
