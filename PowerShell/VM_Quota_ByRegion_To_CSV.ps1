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

#Portion of script from https://gist.github.com/blakedrumm/becc4c306ea8913c76a776c2310084ec -  Author: Blake Drumm - Contact: blakedrumm@microsoft.com

# Set Variables
$tenantid="EnterTenantID"
$startingsubscription="EnterSubscriptionIDtoStart"
$location = "eastus2"

# Connect-AzAccount
connect-AzAccount -tenant $tenantid -Subscription $startingsubscription

# Initialize an empty array to store all the data
$allQuotaData = @()

set-azcontext -Tenant $tenantid -Subscription $startingsubscription

$subscriptions=get-azsubscription -tenantid $tenantid 

foreach ($subscription in $subscriptions) {
set-azcontext -subscription $subscription.Name | Out-Null

$subscription = (Get-AzContext).Subscription
$subscriptionId = $subscription.Id
$subscriptionName = $subscription.Name

# Retrieve usage and quota information for Virtual Machines
Write-Host "Gathering VM quota and usage data for $location $subscriptionName"

# Get the resource usage details for the current region (Virtual Machines) and current subscription
$vmUsageDetails = Get-AzVMUsage -Location $Location

foreach ($usage in $vmUsageDetails)
{
	$currentUsagePercent = if ($usage.Limit -gt 0) { [math]::Round(($usage.CurrentValue / $usage.Limit) * 100, 2) }
	else { 0 }
	
	$allQuotaData += [PSCustomObject]@{
		SubscriptionName = $subscription.Name 
		SubscriptionId   = $subscriptionId
		Resource		 = "Virtual Machines"
		ResourceType	 = "Microsoft.Compute"
		QuotaName	     = $usage.Name.LocalizedValue
		Region		     = $location
		CurrentUsage	 = $usage.CurrentValue
		Limit		     = $usage.Limit
		UsagePercent	 = $currentUsagePercent
	}
  }
}

# Convert the gathered data into a single table and display it
$allQuotaData | Sort-Object SubscriptionName -Descending | Format-Table -Property QuotaName, Region, Resource, SubscriptionName, SubscriptionId, CurrentUsage, Limit, UsagePercent -AutoSize

$allQuotaData | Export-Csv -Path "AzureQuotaUsage.csv" -NoTypeInformation

