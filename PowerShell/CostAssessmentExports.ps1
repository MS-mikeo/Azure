Install-Module -Name Az.ResourceGraph

#Date
$Date=Get-Date -UFormat "%Y-%m-%d" 

#Outputfolder
$OutputFolder="C:\ACOA_Output-" + $Date

#Creating Output folder
Remove-Item -Force $OutputFolder -Recurse
mkdir -p $OutputFolder

############################################################
####################### GENERAL PAGE #######################
############################################################

# General Page -> resourceDistributionbyRegion
$GENERAL_resourceDistributionByRegion_Query= Search-AzGraph -Query "resources | summarize count() by location"
foreach ($item in $GENERAL_resourceDistributionByRegion_Query) {
    $GENERAL_resourceDistributionByRegion = New-Object PSObject -Property @{
        Location = $item.location;  
        Count = $item.count_;              
        }
    $GENERAL_resourceDistributionByRegion | select-object "Location", "Count" | Export-CSV "$OutputFolder\GENERAL_resourceDistributionByRegion.csv"  -Append -NoTypeInformation
}

# General Page -> resourceDistributionBySubscription
$GENERAL_resourceDistributionBySubscription_Query= Search-AzGraph -Query "ResourceContainers | where type =~ 'Microsoft.Resources/subscriptions' | project SubscriptionName = name, subscriptionId | join (Resources | summarize resourceCount=count() by subscriptionId) on subscriptionId"
foreach ($item in $GENERAL_resourceDistributionBySubscription_Query) {
    $GENERAL_resourceDistributionBySubscription = New-Object PSObject -Property @{
        SubscriptionName = $item.SubscriptionName;
        SubscriptionId   = $item.SubscriptionId;  
        resourceCount    = $item.resourceCount;              
        }
    $GENERAL_resourceDistributionBySubscription | select-object "SubscriptionName", "SubscriptionId", "resourceCount" | Export-CSV "$OutputFolder\GENERAL_resourceDistributionBySubscription.csv"  -Append -NoTypeInformation
}

# General Page -> vmPerSKU
$GENERAL_vmPerSKU_Query= Search-AzGraph -Query "resources | where type in~ ('Microsoft.Compute/virtualMachines','Microsoft.Compute/virtualMachineScaleSets') | project SKU = tostring(properties.hardwareProfile.vmSize) | summarize count() by SKU"
foreach ($item in $GENERAL_vmPerSKU_Query) {
    $GENERAL_vmPerSKU = New-Object PSObject -Property @{
        SKU   = $item.SKU;  
        Count = $item.count_;              
        }
    $GENERAL_vmPerSKU | select-object "SKU", "Count" | Export-CSV "$OutputFolder\GENERAL_vmPerSKU.csv"  -Append -NoTypeInformation
}

# General Page -> taggedResourceGroup
$GENERAL_taggedResourceGroup_Query= Search-AzGraph -Query "ResourceContainers | where type =~ 'microsoft.resources/subscriptions/resourcegroups' | extend TagBool = iff(tags != '' and tags != '[]', 'Tagged','Untagged') | summarize count() by TagBool"
foreach ($item in $GENERAL_taggedResourceGroup_Query) {
    $GENERAL_taggedResourceGroup = New-Object PSObject -Property @{
        TagBool = $item.TagBool;  
        Count   = $item.count_;              
        }
    $GENERAL_taggedResourceGroup | select-object "TagBool", "Count" | Export-CSV "$OutputFolder\GENERAL_taggedResourceGroup.csv"  -Append -NoTypeInformation
}

# General Page -> taggedResources
$GENERAL_taggedResources_Query = Search-AzGraph -Query "Resources | extend TagBool = iff(tags != '' and tags != '[]', 'Tagged','Untagged') | summarize count() by TagBool"
foreach ($item in $GENERAL_taggedResources_Query) {
    $GENERAL_taggedResources = New-Object PSObject -Property @{
        TagBool = $item.TagBool;  
        Count   = $item.count_;              
        }
    $GENERAL_taggedResources | select-object "TagBool", "Count" | Export-CSV "$OutputFolder\GENERAL_taggedResources.csv"  -Append -NoTypeInformation
}

# General Page -> untaggedResourcesDetails
$GENERAL_untaggedResourcesDetails_Query = Search-AzGraph -Query "resources | where tags =~ '' or tags =~ '{}' | project id, type, resourceGroup=tostring(split(id,'/providers/')[0]), subscriptionId"
foreach ($item in $GENERAL_untaggedResourcesDetails_Query) {
    $GENERAL_untaggedResourcesDetails = New-Object PSObject -Property @{
        resourceID      = $item.id;
        type            = $item.type;  
        ResourceGroupID = $item.ResourceGroup;         
        subscriptionId  = $item.subscriptionId;              
        }
    $GENERAL_untaggedResourcesDetails | select-object "resourceID", "type", "ResourceGroupID", "subscriptionId"  | Export-CSV "$OutputFolder\GENERAL_untaggedResourcesDetails.csv"  -Append -NoTypeInformation
}

# General Page -> taggedResourceGroupDetails
$GENERAL_taggedResourceGroupDetails_Query = Search-AzGraph -Query "ResourceContainers | where type =~ 'microsoft.resources/subscriptions/resourcegroups'| where tags !~ '' and tags != '{}' | extend resourceGroupName=id, RGLocation=location, RGTags=tags | project resourceGroupName, RGTags, RGLocation, subscriptionId"
foreach ($item in $GENERAL_taggedResourceGroupDetails_Query) {
    $GENERAL_taggedResourceGroupDetails = New-Object PSObject -Property @{
        resourceGroupID = $item.resourceGroupName;  
        RGTags          = $item.RGTags;         
        RGLocation      = $item.RGLocation; 
        subscriptionId  = $item.subscriptionId;              
        }
    $GENERAL_taggedResourceGroupDetails | select-object "resourceGroupID", "RGTags", "RGLocation", "subscriptionId" | Export-CSV "$OutputFolder\GENERAL_taggedResourceGroupDetails.csv"  -Append -NoTypeInformation
}

# General Page -> untaggedResourceGroupDetails
$GENERAL_untaggedResourceGroupDetails_Query = Search-AzGraph -Query "ResourceContainers | where type =~ 'microsoft.resources/subscriptions/resourcegroups' | where tags =~ '' or tags =~ '{}' | extend resourceGroupName=id, RGLocation=location | project resourceGroupName, RGLocation, subscriptionId"
foreach ($item in $GENERAL_untaggedResourceGroupDetails_Query) {
    $GENERAL_untaggedResourceGroupDetails = New-Object PSObject -Property @{
        resourceGroupID = $item.resourceGroupName;             
        RGLocation      = $item.RGLocation; 
        subscriptionId  = $item.subscriptionId;              
        }
    $GENERAL_untaggedResourceGroupDetails | select-object "resourceGroupID", "RGLocation", "subscriptionId" | Export-CSV "$OutputFolder\GENERAL_untaggedResourceGroupDetails.csv"  -Append -NoTypeInformation
}

############################################################
####################### COMPUTE PAGE #######################
############################################################

# Compute Page -> vmStoppedStateQuery
$COMPUTE_vmStoppedState_Query = Search-AzGraph -Query "resources | where type =~ 'microsoft.compute/virtualmachines' | where tostring(properties.extended.instanceView.powerState.displayStatus) !in ('VM deallocated', 'VM running') `
| extend PowerState=tostring(properties.extended.instanceView.powerState.displayStatus) | project id, PowerState, location, resourceGroup, subscriptionId, tags | order by id asc"
foreach ($item in $COMPUTE_vmStoppedState_Query) {
    $COMPUTE_vmStoppedState = New-Object PSObject -Property @{
        vmID           = $item.id;             
        PowerState     = $item.PowerState; 
        location       = $item.location;
        resourceGroup  = $item.resourceGroup;        
        subscriptionId = $item.subscriptionId;
        tags           = $item.tags;   
        ResourceId     = $item.ResourceId;               
        }
    $COMPUTE_vmStoppedState | select-object "vmID", "PowerState", "location", "resourceGroup", "subscriptionId", "tags", "ResourceId" | Export-CSV "$OutputFolder\COMPUTE_vmStoppedState.csv"  -Append -NoTypeInformation
}

# Compute Page -> allVirtualMachinesQuery
$COMPUTE_allVirtualMachines_Query = Search-AzGraph -Query "Resources | where type =~ 'Microsoft.Compute/virtualMachines' `
| extend  TotalDataDisks=array_length(properties.storageProfile.dataDisks), TotalNICs=array_length(properties.networkProfile.networkInterfaces), VMSKU=tostring(properties.hardwareProfile.vmSize) `
| project id, VMSKU, TotalDataDisks, TotalNICs, location, resourceGroup, subscriptionId, tags | order by VMSKU asc"
foreach ($item in $COMPUTE_allVirtualMachines_Query) {
    $COMPUTE_allVirtualMachines = New-Object PSObject -Property @{
        vmID           = $item.id;             
        VMSKU          = $item.VMSKU; 
        TotalDataDisks = $item.TotalDataDisks;
        TotalNICs      = $item.TotalNICs;
        location       = $item.location;
        resourceGroup  = $item.resourceGroup;        
        subscriptionId = $item.subscriptionId;
        tags           = $item.tags;   
        ResourceId     = $item.ResourceId;               
        }
    $COMPUTE_allVirtualMachines | select-object "vmID", "VMSKU", "TotalDataDisks", "TotalNICs", "location", "resourceGroup", "subscriptionId", "tags", "ResourceId" | Export-CSV "$OutputFolder\COMPUTE_allVirtualMachines.csv"  -Append -NoTypeInformation
}

# Compute Page -> webFunctionStatusQuery-TOUCHED_UP_allWebApps
$COMPUTE_webFunctionStatus_Query = Search-AzGraph -Query "resources | where type =~ 'Microsoft.Web/sites' `
| extend AppServicePlanId=tostring(properties.serverFarmId), AppName=tostring(properties.name),AppSku=tostring(properties.sku), `
kind, Status=tostring(properties.state), location, subscriptionId | extend AppServicePlanName = tostring(split(AppServicePlanId,'/Microsoft.Web/serverfarms/')[1]) `
| extend resourceGroup = tostring(split(id,'/resourceGroups/')[1]) | extend resourceGroupName = tostring(split(resourceGroup,'/')[0]) `
| join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId `   
| project AppName, AppSku, kind, Status, location, resourceGroupName, subscriptionName, AppServicePlanName, AppServicePlanId, tags"
foreach ($item in $COMPUTE_webFunctionStatus_Query) {
    $COMPUTE_webFunctionStatus = New-Object PSObject -Property @{
        AppName            = $item.AppName;             
        AppSku             = $item.AppSku;
        kind               = $item.kind;
        Status             = $item.Status;
        location           = $item.location;
        resourceGroupName  = $item.resourceGroupName;
        subscriptionName   = $item.subscriptionName;
        AppServicePlanName = $item.AppServicePlanName; 
        AppServicePlanId   = $item.AppServicePlanId; 
        tags               = $item.tags;                     
        }
    $COMPUTE_webFunctionStatus | select-object "AppName", "AppSku", "kind", "Status", "location", "resourceGroupName", "subscriptionName", "AppServicePlanName", "AppServicePlanId", "tags" | Export-CSV "$OutputFolder\COMPUTE_allWebApps.csv"  -Append -NoTypeInformation
}

# Compute Page -> webFunctionStatusQuery-TOUCHED_UP_allWebApps
$COMPUTE_webFunctionStatus_Query = Search-AzGraph -Query "resources | where type =~ 'Microsoft.Web/sites' `
| extend AppServicePlanId=tostring(properties.serverFarmId), AppName=tostring(properties.name),AppSku=tostring(properties.sku), `
kind, Status=tostring(properties.state), location, subscriptionId | extend AppServicePlanName = tostring(split(AppServicePlanId,'/Microsoft.Web/serverfarms/')[1]) `
| extend resourceGroup = tostring(split(id,'/resourceGroups/')[1]) | extend resourceGroupName = tostring(split(resourceGroup,'/')[0]) `
| join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId `   
| project AppName, AppSku, kind, Status, location, resourceGroupName, subscriptionName, AppServicePlanName, AppServicePlanId, tags"
foreach ($item in $COMPUTE_webFunctionStatus_Query) {
    $COMPUTE_webFunctionStatus = New-Object PSObject -Property @{
        AppName            = $item.AppName;             
        AppSku             = $item.AppSku;
        kind               = $item.kind;
        Status             = $item.Status;
        location           = $item.location;
        resourceGroupName  = $item.resourceGroupName;
        subscriptionName   = $item.subscriptionName;
        AppServicePlanName = $item.AppServicePlanName; 
        AppServicePlanId   = $item.AppServicePlanId; 
        tags               = $item.tags;                     
        }
    $COMPUTE_webFunctionStatus | select-object "AppName", "AppSku", "kind", "Status", "location", "resourceGroupName", "subscriptionName", "AppServicePlanName", "AppServicePlanId", "tags" | Export-CSV "$OutputFolder\COMPUTE_allWebApps.csv"  -Append -NoTypeInformation
}


# Compute Page -> webFunctionStatusQuery-TOUCHED_UP_allWebApps
$COMPUTE_webFunctionStatus_Query = Search-AzGraph -Query "resources | where type =~ 'Microsoft.Web/sites' `
| extend AppServicePlanId=tostring(properties.serverFarmId), AppName=tostring(properties.name),AppSku=tostring(properties.sku), `
kind, Status=tostring(properties.state), location, subscriptionId | extend AppServicePlanName = tostring(split(AppServicePlanId,'/Microsoft.Web/serverfarms/')[1]) `
| extend resourceGroup = tostring(split(id,'/resourceGroups/')[1]) | extend resourceGroupName = tostring(split(resourceGroup,'/')[0]) `
| join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId `   
| project AppName, AppSku, kind, Status, location, resourceGroupName, subscriptionName, AppServicePlanName, AppServicePlanId, tags"
foreach ($item in $COMPUTE_webFunctionStatus_Query) {
    $COMPUTE_webFunctionStatus = New-Object PSObject -Property @{
        AppName            = $item.AppName;             
        AppSku             = $item.AppSku;
        kind               = $item.kind;
        Status             = $item.Status;
        location           = $item.location;
        resourceGroupName  = $item.resourceGroupName;
        subscriptionName   = $item.subscriptionName;
        AppServicePlanName = $item.AppServicePlanName; 
        AppServicePlanId   = $item.AppServicePlanId; 
        tags               = $item.tags;                     
        }
    $COMPUTE_webFunctionStatus | select-object "AppName", "AppSku", "kind", "Status", "location", "resourceGroupName", "subscriptionName", "AppServicePlanName", "AppServicePlanId", "tags" | Export-CSV "$OutputFolder\COMPUTE_allWebApps.csv"  -Append -NoTypeInformation
}

# Compute Page -> appServicePlanDetailsQuery-TOUCHED_UP_allAppServicePlans
$COMPUTE_appServicePlanDetails_Query=Search-AzGraph -Query "resources | where type == 'microsoft.web/serverfarms'  `
| extend  planId = tolower(tostring(id)), skuname = tostring(sku.name), skutier = tostring(sku.tier), workers = tostring(properties.numberOfWorkers), maxworkers = tostring(properties.maximumNumberOfWorkers) `
| join kind = leftouter (resources | where type == 'microsoft.insights/autoscalesettings' `
| project planId = tolower(tostring(properties.targetResourceUri)), PredictiveAutoscale = properties.predictiveAutoscalePolicy.scaleMode, AutoScaleProfiles = properties.profiles) on planId `
| join kind = inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId `
| extend resourceGroup = tostring(split(id,'/resourceGroups/')[1]) | extend resourceGroupName = tostring(split(resourceGroup,'/')[0]) | project-away id, planId1 `
| project planId, name, skuname, skutier, location, workers, maxworkers, resourceGroupName, subscriptionName, PredictiveAutoscale, AutoScaleProfiles, tags"
foreach ($item in $COMPUTE_appServicePlanDetails_Query) {
    $COMPUTE_appServicePlanDetails = New-Object PSObject -Property @{
        planId            = $item.planId;             
        name             = $item.name;
        skuname              = $item.skuname;
        skutier             = $item.skutier;
        location           = $item.location;
        workers             = $item.workers;
        maxworkers          = $item.maxworkers;
        resourceGroupName  = $item.resourceGroupName;
        subscriptionName   = $item.subscriptionName;
        PredictiveAutoscale = $item.PredictiveAutoscale; 
        AutoScaleProfiles   = $item.AutoScaleProfiles; 
        tags               = $item.tags;                     
        }
    $COMPUTE_appServicePlanDetails | select-object "planId", "name", "skuname", "skutier", "location", "workers", "maxworkers", "resourceGroupName", "subscriptionName", "PredictiveAutoscale", "AutoScaleProfiles", "tags" | Export-CSV "$OutputFolder\COMPUTE_allAppServicePlans.csv"  -Append -NoTypeInformation

# Had to remove "| join kind = inner (resources | where type == 'microsoft.web/serverfarms' | extend id=tolower(tostring(id)) | distinct id) on '$left.planId' == '$right.id" after "| project planId = tolower(tostring(properties.targetResourceUri)), PredictiveAutoscale = properties.predictiveAutoscalePolicy.scaleMode, AutoScaleProfiles = properties.profiles) on planId"
# Noting in case this causes an unforeseen issue later, but not seeing why it is needed.
}
