# Changes needed before finished:
# 1.) Update all Subscription IDs to have Subscription name in any GENERAL and COMPUTE exports
# 2.) Add Advisor and Orphan resources export (and any other beneficial ones - empty app service plans that are not serverless)
# 3.) Review/update beginning logic for module/folder checks
# 4.) Add actual time to folder and run check before deleting to get rid of error
# 5.) NETWORKING SECTION: Firewall, VNG, and Front Door Metrics - review for powershell

$moduleName = "Az.Accounts"
if (!(Get-Module -ListAvailable -Name $moduleName)) {
    Install-Module -Name $moduleName 
}
$moduleName = "Az.ResourceGraph"
if (!(Get-Module -ListAvailable -Name $moduleName)) {
    Install-Module -Name $moduleName 
}

Import-module Az.Accounts

Import-module Az.ResourceGraph

Connect-AzAccount


#Date
$Date=Get-Date -UFormat "%Y-%m-%d" 

#Outputfolder
$OutputFolder="C:\ACOA_Output-" + $Date

#Creating Output folder
Remove-Item -Force $OutputFolder -Recurse
mkdir -p $OutputFolder
mkdir -p $OutputFolder\WorkbookOutput
mkdir -p $OutputFolder\WorkbookOutput\General
mkdir -p $OutputFolder\WorkbookOutput\Compute
#AHUB Placeholder
mkdir -p $OutputFolder\WorkbookOutput\Storage
mkdir -p $OutputFolder\WorkbookOutput\Networking
mkdir -p $OutputFolder\WorkbookOutput\Monitoring
mkdir -p $OutputFolder\WorkbookOutput\Monitoring\Workspaces_Usage
mkdir -p $OutputFolder\Subscriptions

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
    $GENERAL_resourceDistributionByRegion | select-object "Location", "Count" | Export-CSV "$OutputFolder\WorkbookOutput\General\GENERAL_resourceDistributionByRegion.csv"  -Append -NoTypeInformation
}

# General Page -> resourceDistributionBySubscription
$GENERAL_resourceDistributionBySubscription_Query= Search-AzGraph -Query "ResourceContainers | where type =~ 'Microsoft.Resources/subscriptions' | project SubscriptionName = name, subscriptionId | join (Resources | summarize resourceCount=count() by subscriptionId) on subscriptionId"
foreach ($item in $GENERAL_resourceDistributionBySubscription_Query) {
    $GENERAL_resourceDistributionBySubscription = New-Object PSObject -Property @{
        SubscriptionName = $item.SubscriptionName;
        SubscriptionId   = $item.SubscriptionId;  
        resourceCount    = $item.resourceCount;              
        }
    $GENERAL_resourceDistributionBySubscription | select-object "SubscriptionName", "SubscriptionId", "resourceCount" | Export-CSV "$OutputFolder\WorkbookOutput\General\GENERAL_resourceDistributionBySubscription.csv"  -Append -NoTypeInformation
}

# General Page -> vmPerSKU
$GENERAL_vmPerSKU_Query= Search-AzGraph -Query "resources | where type in~ ('Microsoft.Compute/virtualMachines','Microsoft.Compute/virtualMachineScaleSets') | project SKU = tostring(properties.hardwareProfile.vmSize) | summarize count() by SKU"
foreach ($item in $GENERAL_vmPerSKU_Query) {
    $GENERAL_vmPerSKU = New-Object PSObject -Property @{
        SKU   = $item.SKU;  
        Count = $item.count_;              
        }
    $GENERAL_vmPerSKU | select-object "SKU", "Count" | Export-CSV "$OutputFolder\WorkbookOutput\General\GENERAL_vmPerSKU.csv"  -Append -NoTypeInformation
}

# General Page -> taggedResourceGroup
$GENERAL_taggedResourceGroup_Query= Search-AzGraph -Query "ResourceContainers | where type =~ 'microsoft.resources/subscriptions/resourcegroups' | extend TagBool = iff(tags != '' and tags != '[]', 'Tagged','Untagged') | summarize count() by TagBool"
foreach ($item in $GENERAL_taggedResourceGroup_Query) {
    $GENERAL_taggedResourceGroup = New-Object PSObject -Property @{
        TagBool = $item.TagBool;  
        Count   = $item.count_;              
        }
    $GENERAL_taggedResourceGroup | select-object "TagBool", "Count" | Export-CSV "$OutputFolder\WorkbookOutput\General\GENERAL_taggedResourceGroup.csv"  -Append -NoTypeInformation
}

# General Page -> taggedResources
$GENERAL_taggedResources_Query = Search-AzGraph -Query "Resources | extend TagBool = iff(tags != '' and tags != '[]', 'Tagged','Untagged') | summarize count() by TagBool"
foreach ($item in $GENERAL_taggedResources_Query) {
    $GENERAL_taggedResources = New-Object PSObject -Property @{
        TagBool = $item.TagBool;  
        Count   = $item.count_;              
        }
    $GENERAL_taggedResources | select-object "TagBool", "Count" | Export-CSV "$OutputFolder\WorkbookOutput\General\GENERAL_taggedResources.csv"  -Append -NoTypeInformation
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
    $GENERAL_untaggedResourcesDetails | select-object "resourceID", "type", "ResourceGroupID", "subscriptionId"  | Export-CSV "$OutputFolder\WorkbookOutput\General\GENERAL_untaggedResourcesDetails.csv"  -Append -NoTypeInformation
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
    $GENERAL_taggedResourceGroupDetails | select-object "resourceGroupID", "RGTags", "RGLocation", "subscriptionId" | Export-CSV "$OutputFolder\WorkbookOutput\General\GENERAL_taggedResourceGroupDetails.csv"  -Append -NoTypeInformation
}

# General Page -> untaggedResourceGroupDetails
$GENERAL_untaggedResourceGroupDetails_Query = Search-AzGraph -Query "ResourceContainers | where type =~ 'microsoft.resources/subscriptions/resourcegroups' | where tags =~ '' or tags =~ '{}' | extend resourceGroupName=id, RGLocation=location | project resourceGroupName, RGLocation, subscriptionId"
foreach ($item in $GENERAL_untaggedResourceGroupDetails_Query) {
    $GENERAL_untaggedResourceGroupDetails = New-Object PSObject -Property @{
        resourceGroupID = $item.resourceGroupName;             
        RGLocation      = $item.RGLocation; 
        subscriptionId  = $item.subscriptionId;              
        }
    $GENERAL_untaggedResourceGroupDetails | select-object "resourceGroupID", "RGLocation", "subscriptionId" | Export-CSV "$OutputFolder\WorkbookOutput\General\GENERAL_untaggedResourceGroupDetails.csv"  -Append -NoTypeInformation
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
    $COMPUTE_vmStoppedState | select-object "vmID", "PowerState", "location", "resourceGroup", "subscriptionId", "tags", "ResourceId" | Export-CSV "$OutputFolder\WorkbookOutput\Compute\COMPUTE_vmStoppedState.csv"  -Append -NoTypeInformation
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
    $COMPUTE_allVirtualMachines | select-object "vmID", "VMSKU", "TotalDataDisks", "TotalNICs", "location", "resourceGroup", "subscriptionId", "tags", "ResourceId" | Export-CSV "$OutputFolder\WorkbookOutput\Compute\COMPUTE_allVirtualMachines.csv"  -Append -NoTypeInformation
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
    $COMPUTE_webFunctionStatus | select-object "AppName", "AppSku", "kind", "Status", "location", "resourceGroupName", "subscriptionName", "AppServicePlanName", "AppServicePlanId", "tags" | Export-CSV "$OutputFolder\WorkbookOutput\Compute\COMPUTE_allWebApps.csv"  -Append -NoTypeInformation
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
    $COMPUTE_webFunctionStatus | select-object "AppName", "AppSku", "kind", "Status", "location", "resourceGroupName", "subscriptionName", "AppServicePlanName", "AppServicePlanId", "tags" | Export-CSV "$OutputFolder\WorkbookOutput\Compute\COMPUTE_allWebApps.csv"  -Append -NoTypeInformation
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
    $COMPUTE_webFunctionStatus | select-object "AppName", "AppSku", "kind", "Status", "location", "resourceGroupName", "subscriptionName", "AppServicePlanName", "AppServicePlanId", "tags" | Export-CSV "$OutputFolder\WorkbookOutput\Compute\COMPUTE_allWebApps.csv"  -Append -NoTypeInformation
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
        planId              = $item.planId;             
        name                = $item.name;
        skuname             = $item.skuname;
        skutier             = $item.skutier;
        location            = $item.location;
        workers             = $item.workers;
        maxworkers          = $item.maxworkers;
        resourceGroupName   = $item.resourceGroupName;
        subscriptionName    = $item.subscriptionName;
        PredictiveAutoscale = $item.PredictiveAutoscale; 
        AutoScaleProfiles   = $item.AutoScaleProfiles; 
        tags                = $item.tags;                     
        }
    $COMPUTE_appServicePlanDetails | select-object "planId", "name", "skuname", "skutier", "location", "workers", "maxworkers", "resourceGroupName", "subscriptionName", "PredictiveAutoscale", "AutoScaleProfiles", "tags" | Export-CSV "$OutputFolder\WorkbookOutput\Compute\COMPUTE_allAppServicePlans.csv"  -Append -NoTypeInformation

# Had to remove "| join kind = inner (resources | where type == 'microsoft.web/serverfarms' | extend id=tolower(tostring(id)) | distinct id) on '$left.planId' == '$right.id" after "| project planId = tolower(tostring(properties.targetResourceUri)), PredictiveAutoscale = properties.predictiveAutoscalePolicy.scaleMode, AutoScaleProfiles = properties.profiles) on planId"
# Noting in case this causes an unforeseen issue later, but not seeing why it is needed.
}

# Compute Page -> webAppandPlanMerge-TOUCHED_UP
$COMPUTE_webAppandPlanMerge_Query=Search-AzGraph -Query "resources | where type =~ 'Microsoft.Web/sites' `
| extend ASPplanid=tolower(tostring(properties.serverFarmId)), APPName=tostring(properties.name), APPSku=tostring(properties.sku), APPkind=tostring(properties.kind), `
APPStatus=tostring(properties.state), APPlocation=tostring(properties.location), APPsubscriptionId=tostring(properties.state) `
| extend APPServicePlanName = tostring(split(ASPplanid,'/microsoft.web/serverfarms/')[1]) | extend APPresourceGroup = tostring(split(id,'/resourceGroups/')[1]) `
| extend APPresourceGroupName = tostring(split(APPresourceGroup,'/')[0])| join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' `
| project subscriptionId, APPsubscriptionName = name) on subscriptionId | project APPName, APPSku, APPkind, APPStatus, APPresourceGroupName, APPsubscriptionName, APPServicePlanName, ASPplanid, APPtags = tags `
| join  kind= fullouter (resources | where type == 'microsoft.web/serverfarms' | extend  ASPplanid = tolower(tostring(id)), ASPskuname = tostring(sku.name), ASPskutier = tostring(sku.tier) `
| join kind = inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId `
| extend ASPresourceGroup = tostring(split(id,'/resourceGroups/')[1]) | extend ASPresourceGroupName = tostring(split(resourceGroup,'/')[0]) `
| project ASPplanid, ASPname = tolower(name), ASPskuname, ASPskutier, ASPlocation = location,  ASPresourceGroupName, ASPsubscriptionName = subscriptionName,  ASPtags = tags) on ASPplanid | sort by ASPplanid1 asc | project-away ASPplanid"
foreach ($item in $COMPUTE_webAppandPlanMerge_Query) {
    $COMPUTE_webAppandPlanMerge = New-Object PSObject -Property @{
        APPName               = $item.APPName ;             
        APPSku                = $item.APPSku;
        APPkind               = $item.APPkind ;
        APPStatus             = $item.APPStatus;
        APPresourceGroupName  = $item.APPresourceGroupName;
        APPsubscriptionName   = $item.APPsubscriptionName;        
        ASPplanid             = $item.ASPplanid;       
        ASPName               = $item.ASPName; 
        ASPskuname            = $item.ASPskuname;
        ASPskutier            = $item.ASPskutier; 
        ASPlocation           = $item.ASPlocation; 
        ASPresourceGroupName  = $item.ASPresourceGroupName; 
        ASPsubscriptionName   = $item.ASPsubscriptionName; 
        ASPtags               = $item.ASPtags;
        APPtags               = $item.APPtags;                    
        }
    $COMPUTE_webAppandPlanMerge | select-object "APPName", "APPSku", "APPkind", "APPStatus", "APPresourceGroupName", "APPsubscriptionName", "ASPplanid1", `
    "ASPName", "ASPskuname", "ASPskutier", "ASPlocation", "ASPresourceGroupName", "ASPsubscriptionName", "ASPtags", "APPtags" | Export-CSV "$OutputFolder\WorkbookOutput\Compute\COMPUTE_webAppandPlanMerge.csv"  -Append -NoTypeInformation

# This query export will allow for identifying empty App Service Plans.  There still may not be a cost associated with certain SKUS, but it makes this investigation much easier.
}

# Compute Page -> aksQuery
$COMPUTE_aks_Query=Search-AzGraph -Query "resources | where type == 'microsoft.containerservice/managedclusters' | extend Sku = tostring(sku.name), Tier = tostring(sku.tier), AgentPoolProfiles = properties.agentPoolProfiles `
| mvexpand AgentPoolProfiles | extend ProfileName = tostring(AgentPoolProfiles.name), mode = AgentPoolProfiles.mode, AutoScaleEnabled = AgentPoolProfiles.enableAutoScaling, SpotVM = AgentPoolProfiles.scaleSetPriority, `
VMSize = tostring(AgentPoolProfiles.vmSize), minCount = tostring(AgentPoolProfiles.minCount), maxCount = tostring(AgentPoolProfiles.maxCount), nodeCount = tostring(AgentPoolProfiles.['count']) `
| join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId `
| project id, subscriptionId, subscriptionName, resourceGroup, name, ProfileName, Sku, Tier, mode, AutoScaleEnabled, SpotVM, VMSize, nodeCount, minCount, maxCount, location"
foreach ($item in $COMPUTE_aks_Query) {
    $COMPUTE_aks = New-Object PSObject -Property @{
        id               = $item.id ;             
        subscriptionId   = $item.subscriptionId;
        subscriptionName = $item.subscriptionName ;
        resourceGroup    = $item.resourceGroup;
        name             = $item.name;
        ProfileName      = $item.ProfileName;        
        Sku              = $item.Sku;       
        Tier             = $item.Tier; 
        mode             = $item.mode;
        AutoScaleEnabled = $item.AutoScaleEnabled; 
        SpotVM           = $item.SpotVM; 
        VMSize           = $item.VMSize; 
        nodeCount        = $item.nodeCount; 
        minCount         = $item.minCount;
        maxCount         = $item.maxCount;   
        location         = $item.location;                    
        }
    $COMPUTE_aks | select-object "id", "subscriptionId", "subscriptionName", "name", "ProfileName", "Sku", "Tier", `
    "mode", "AutoScaleEnabled", "SpotVM", "VMSize", "nodeCount", "minCount", "maxCount", "location" | Export-CSV "$OutputFolder\WorkbookOutput\Compute\COMPUTE_aks.csv"  -Append -NoTypeInformation
}

############################################################
####################### STORAGE PAGE #######################
############################################################

# STORAGE Page -> storageAccountNotV2
$STORAGE_storageAccountNotV2_Query = Search-AzGraph -Query "resources | where type =~ 'Microsoft.Storage/StorageAccounts'| where kind !in~ ('StorageV2', 'FileStorage') `
| extend SAKind = kind, AccessTier = tostring(properties.accessTier), SKUName = tostring(sku.name), SKUTier = tostring(sku.tier), StorageAcctName = tostring(split(id,'/providers/Microsoft.Storage/storageAccounts/')[1]) `
| join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId | order by id asc `
| project subscriptionId, subscriptionName, id, StorageAcctName, resourceGroup, location, SKUName, SKUTier, SAKind, AccessTier, tags"
foreach ($item in $STORAGE_storageAccountNotV2_Query) {
    $STORAGE_storageAccountNotV2 = New-Object PSObject -Property @{
        subscriptionId   = $item.subscriptionId;
        subscriptionName = $item.subscriptionName;
        id               = $item.id;  
        StorageAcctName  = $item.StorageAcctName;            
        resourceGroup    = $item.resourceGroup;   
        location         = $item.location;
        SKUName          = $item.SKUName;        
        SKUTier          = $item.SKUTier;  
        SAKind           = $item.SAKind;  
        AccessTier       = $item.AccessTier;  
        tags             = $item.tags;                       
        }
    $STORAGE_storageAccountNotV2 | select-object "subscriptionId", "subscriptionName", "id", "StorageAcctName", "resourceGroup", "location", "SKUName", "SKUTier", "SAKind", "AccessTier","tags" `
    | Export-CSV "$OutputFolder\WorkbookOutput\Storage\STORAGE_storageAccountNotV2.csv"  -Append -NoTypeInformation
}

# STORAGE Page -> recoveryVaultsReplication-TOUCHED_UP
$STORAGE_recoveryVaultsReplication_Query = Search-AzGraph -Query "Resources | where type == 'microsoft.recoveryservices/vaults' `
| extend skuTier = tostring(sku['tier']), skuName = tostring(sku['name']),  redundancySettings = tostring(properties.redundancySettings['standardTierStorageRedundancy']) `
| join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId `
| project id, name, subscriptionId, subscriptionName, type, location, resourceGroup, skuTier, skuName, redundancySettings, tags | order by id asc"
foreach ($item in $STORAGE_recoveryVaultsReplication_Query) {
    $STORAGE_recoveryVaultsReplication = New-Object PSObject -Property @{
        id                 = $item.id; 
        name               = $item.name; 
        subscriptionId     = $item.subscriptionId;
        subscriptionName   = $item.subscriptionName;         
        type               = $item.type;   
        location           = $item.location;         
        resourceGroup      = $item.resourceGroup;   
        skuTier            = $item.skuTier;  
        skuName            = $item.skuName;     
        redundancySettings = $item.redundancySettings;  
        tags               = $item.tags;                       
        }
    $STORAGE_recoveryVaultsReplication | select-object "id", "name", "subscriptionId", "subscriptionName", "type", "location", "resourceGroup", "skuTier","skuName",  "SAKind", "redundancySettings","tags" `
    | Export-CSV "$OutputFolder\WorkbookOutput\Storage\STORAGE_recoveryVaultsReplication.csv"  -Append -NoTypeInformation
}

# STORAGE Page -> unattachedDisks-TOUCHED_UP
$STORAGE_unattachedDisks_Query = Search-AzGraph -Query "resources | where type =~ 'microsoft.compute/disks'| where isempty(managedBy) | extend diskState = tostring(properties.diskState) | where diskState != 'ActiveSAS' or diskState == 'Unattached' `
| extend id = tolower(id) | join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId `
| join kind = leftouter (resourcechanges | where type == 'microsoft.resources/changes' | where properties.targetResourceType == 'microsoft.compute/disks' | where properties.changeType == 'Update' `
| where isnotnull(properties.changes.managedBy.previousValue) | where isnull(properties.changes.managedBy.newValue) `
| extend timeDetached = todatetime(properties.changeAttributes.timestamp), targetResourceId = tolower(tostring(properties.targetResourceId)) | summarize arg_max(timeDetached,*) by targetResourceId | project id=targetResourceId, timeDetached) on id `
| order by id asc | extend resourceGroup = tostring(split(id,'/providers/')[0]) | extend resourceGroupName = tostring(split(resourceGroup,'/resourcegroups/')[1]) | extend diskName = tostring(split(id,'/providers/microsoft.compute/disks/')[1]) `
| project id, subscriptionId, subscriptionName, resourceGroupName, diskName, diskSizeInGB=properties.diskSizeGB, skuName=sku.name, skuTier=sku.tier, location, timeCreated=properties.timeCreated, timeDetached, tags"
foreach ($item in $STORAGE_unattachedDisks_Query) {
    $STORAGE_unattachedDisks = New-Object PSObject -Property @{
        id                 = $item.id;         
        subscriptionId     = $item.subscriptionId;
        subscriptionName   = $item.subscriptionName;
        resourceGroupName  = $item.resourceGroupName;  
        diskName           = $item.diskName;          
        diskSizeInGB       = $item.diskSizeInGB;
        skuName            = $item.skuName;
        skuTier            = $item.skuTier;          
        location           = $item.location;       
        timeCreated        = $item.timeCreated;  
        timeDetached       = $item.timeDetached;
        tags               = $item.tags;                       
        }
    $STORAGE_unattachedDisks | select-object "id", "subscriptionId", "subscriptionName", "resourceGroupName", "diskName", "diskSizeInGB", "skuName", "skuTier", "location", "timeCreated", "timeDetached", "tags" `
    | Export-CSV "$OutputFolder\WorkbookOutput\Storage\STORAGE_unattachedDisks.csv"  -Append -NoTypeInformation
}

# STORAGE Page -> Get-Old-Snapshots-TOUCHED_UP
$STORAGE_getOldSnapshots_Query = Search-AzGraph -Query "resources | where type == 'microsoft.compute/snapshots' | extend TimeCreated = properties.timeCreated | extend snapshotName = tostring(split(id,'/providers/Microsoft.Compute/snapshots/')[1]) `
| extend sourceResourceId = properties.creationData.sourceResourceId | extend sourceResourceDiskName = tostring(split(sourceResourceId,'/providers/Microsoft.Compute/disks/')[1]) | where TimeCreated < ago(30d) `
| join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId `
| order by id asc | project id, subscriptionId, subscriptionName, resourceGroup, snapshotName, location, TimeCreated, skuName=sku.name, skuTier=sku.tier, diskSizeInGB=properties.diskSizeGB, sourceResourceId, sourceResourceDiskName, tags"
foreach ($item in $STORAGE_getOldSnapshots_Query) {
    $STORAGE_getOldSnapshots = New-Object PSObject -Property @{
        id                     = $item.id;         
        subscriptionId         = $item.subscriptionId;
        subscriptionName       = $item.subscriptionName;
        resourceGroup          = $item.resourceGroup;  
        snapshotName           = $item.snapshotName; 
        location               = $item.location; 
        timeCreated            = $item.timeCreated;     
        skuName                = $item.skuName;
        skuTier                = $item.skuTier;          
        diskSizeInGB           = $item.diskSizeInGB;       
        sourceResourceId       = $item.sourceResourceId; 
        sourceResourceDiskName = $item.sourceResourceDiskName;
        tags                   = $item.tags;                       
        }
    $STORAGE_getOldSnapshots | select-object "id", "subscriptionId", "subscriptionName", "resourceGroup", "snapshotName", "location", "timeCreated", "skuName", "skuTier", "diskSizeInGB", "sourceResourceId", "sourceResourceDiskName", "tags" `
    | Export-CSV "$OutputFolder\WorkbookOutput\Storage\STORAGE_diskSnapshots_olderthan30days.csv"  -Append -NoTypeInformation

# Needs further testing, no old snapshots in dev env, will be able to test towards 12/2023 - MO

}

# STORAGE Page -> Snapshots_using_premium_storage-TOUCHED_UP
$STORAGE_Snapshots_using_premium_storage_Query = Search-AzGraph -Query "resources | where type == 'microsoft.compute/snapshots' | extend TimeCreated = properties.timeCreated | extend snapshotName = tostring(split(id,'/providers/Microsoft.Compute/snapshots/')[1]) `
| extend sourceResourceId = properties.creationData.sourceResourceId | extend sourceResourceDiskName = tostring(split(sourceResourceId,'/providers/Microsoft.Compute/disks/')[1]) | where sku.name contains 'Premium' `
| join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId `
| order by id asc | project id, subscriptionId, subscriptionName, resourceGroup, snapshotName, location, TimeCreated, skuName=sku.name, skuTier=sku.tier, diskSizeInGB=properties.diskSizeGB, sourceResourceId, sourceResourceDiskName, tags"
foreach ($item in $STORAGE_Snapshots_using_premium_storage_Query) {
    $STORAGE_Snapshots_using_premium_storage = New-Object PSObject -Property @{
        id                     = $item.id;         
        subscriptionId         = $item.subscriptionId;
        subscriptionName       = $item.subscriptionName;
        resourceGroup          = $item.resourceGroup;  
        snapshotName           = $item.snapshotName; 
        location               = $item.location; 
        timeCreated            = $item.timeCreated;     
        skuName                = $item.skuName;
        skuTier                = $item.skuTier;          
        diskSizeInGB           = $item.diskSizeInGB;       
        sourceResourceId       = $item.sourceResourceId; 
        sourceResourceDiskName = $item.sourceResourceDiskName;
        tags                   = $item.tags;                       
        }
    $STORAGE_Snapshots_using_premium_storage | select-object "id", "subscriptionId", "subscriptionName", "resourceGroup", "snapshotName", "location", "timeCreated", "skuName", "skuTier", "diskSizeInGB", "sourceResourceId", "sourceResourceDiskName", "tags" `
    | Export-CSV "$OutputFolder\WorkbookOutput\Storage\STORAGE_Snapshots_using_premium_storage.csv"  -Append -NoTypeInformation
}

$STORAGE_Snapshots_Orphaned_Query = Search-AzGraph -Query "
resources 
| where type == 'microsoft.compute/snapshots' 
| extend TimeCreated = properties.timeCreated 
| extend snapshotName = tostring(split(id,'/providers/Microsoft.Compute/snapshots/')[1]) 
| extend sourceResourceId = tostring(properties.creationData.sourceResourceId)
| extend sourceResourceDiskName = tostring(split(sourceResourceId,'/providers/Microsoft.Compute/disks/')[1]) 
| join kind=fullouter    (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId 
| order by id asc | project id, subscriptionId, subscriptionName, resourceGroup, snapshotName, location, TimeCreated, skuName=sku.name, skuTier=sku.tier, diskSizeInGB=properties.diskSizeGB, sourceResourceId, sourceResourceDiskName, tags
|join  kind=fullouter  (resources
| where type =~ 'microsoft.compute/disks'
| join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' 
| project subscriptionId, subscriptionName = name) on subscriptionId 
| extend sourceResourceId = tostring(id)
| extend id = tolower(id)
| extend resourceGroupName = tostring(split(resourceGroup,'/resourcegroups/')[1]) 
| extend diskName = tostring(split(id,'/providers/microsoft.compute/disks/')[1]) 
| project id, subscriptionId,  resourceGroup, diskName, diskSizeInGB=properties.diskSizeGB, skuName=sku.name, skuTier=sku.tier, location, timeCreated=properties.timeCreated, tags, sourceResourceId) on sourceResourceId
| where id != '' and sourceResourceId1 == '' 
| project id, subscriptionId, subscriptionName, resourceGroup, snapshotName, location, TimeCreated, skuName, skuTier, diskSizeInGB, sourceResourceId, sourceResourceDiskName, tags
"
foreach ($item in $STORAGE_Snapshots_Orphaned_Query) {
    $STORAGE_Snapshots_Orphaned = New-Object PSObject -Property @{
        id                     = $item.id;         
        subscriptionId         = $item.subscriptionId;
        subscriptionName       = $item.subscriptionName;
        resourceGroup          = $item.resourceGroup;  
        snapshotName           = $item.snapshotName; 
        location               = $item.location; 
        timeCreated            = $item.timeCreated;     
        skuName                = $item.skuName;
        skuTier                = $item.skuTier;          
        diskSizeInGB           = $item.diskSizeInGB;       
        sourceResourceId       = $item.sourceResourceId; 
        sourceResourceDiskName = $item.sourceResourceDiskName;
        tags                   = $item.tags;                       
        }
    $STORAGE_Snapshots_Orphaned | select-object "id", "subscriptionId", "subscriptionName", "resourceGroup", "snapshotName", "location", "timeCreated", "skuName", "skuTier", "diskSizeInGB", "sourceResourceId", "sourceResourceDiskName", "tags" `
    | Export-CSV "$OutputFolder\WorkbookOutput\Storage\STORAGE_Snapshots_Orphaned.csv"  -Append -NoTypeInformation
}

# STORAGE Page -> All_Managed_Disks
$STORAGE_Disks_ALL_Query = Search-AzGraph -Query "
resources 
| where type =~ 'microsoft.compute/disks'
| join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' 
| project subscriptionId, subscriptionName = name) on subscriptionId 
| extend id = tolower(id)
| extend resourceGroupName = tostring(split(resourceGroup,'/resourcegroups/')[1]) 
| extend diskName = tostring(split(id,'/providers/microsoft.compute/disks/')[1]) 
| project id, subscriptionId,  resourceGroup, diskName, diskSizeInGB=properties.diskSizeGB, skuName=sku.name, skuTier=sku.tier, location, timeCreated=properties.timeCreated, tags
"
foreach ($item in $STORAGE_Disks_ALL_Query) {
    $STORAGE_Disks_ALL = New-Object PSObject -Property @{
        id                 = $item.id;         
        subscriptionId     = $item.subscriptionId;
        subscriptionName   = $item.subscriptionName;
        resourceGroupName  = $item.resourceGroupName;  
        diskName           = $item.diskName;          
        diskSizeInGB       = $item.diskSizeInGB;
        skuName            = $item.skuName;
        skuTier            = $item.skuTier;          
        location           = $item.location;       
        timeCreated        = $item.timeCreated;  
        timeDetached       = $item.timeDetached;
        tags               = $item.tags;                       
        }
    $STORAGE_Disks_ALL | select-object "id", "subscriptionId", "subscriptionName", "resourceGroupName", "diskName", "diskSizeInGB", "skuName", "skuTier", "location", "timeCreated", "timeDetached", "tags" `
    | Export-CSV "$OutputFolder\WorkbookOutput\Storage\STORAGE_Disks_ALL.csv"  -Append -NoTypeInformation
}

# STORAGE Page -> All Snapshots
$STORAGE_Snapshots_ALL_Query = Search-AzGraph -Query "
resources 
| where type == 'microsoft.compute/snapshots' 
| extend TimeCreated = properties.timeCreated 
| extend snapshotName = tostring(split(id,'/providers/Microsoft.Compute/snapshots/')[1]) 
| extend sourceResourceId = properties.creationData.sourceResourceId 
| extend sourceResourceDiskName = tostring(split(sourceResourceId,'/providers/Microsoft.Compute/disks/')[1]) 
| join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId 
| order by id asc | project id, subscriptionId, subscriptionName, resourceGroup, snapshotName, location, TimeCreated, skuName=sku.name, skuTier=sku.tier, diskSizeInGB=properties.diskSizeGB, sourceResourceId, sourceResourceDiskName, tags
"
foreach ($item in $STORAGE_Snapshots_ALL_Query) {
    $STORAGE_Snapshots_ALL = New-Object PSObject -Property @{
        id                     = $item.id;         
        subscriptionId         = $item.subscriptionId;
        subscriptionName       = $item.subscriptionName;
        resourceGroup          = $item.resourceGroup;  
        snapshotName           = $item.snapshotName; 
        location               = $item.location; 
        timeCreated            = $item.timeCreated;     
        skuName                = $item.skuName;
        skuTier                = $item.skuTier;          
        diskSizeInGB           = $item.diskSizeInGB;       
        sourceResourceId       = $item.sourceResourceId; 
        sourceResourceDiskName = $item.sourceResourceDiskName;
        tags                   = $item.tags;                       
        }
    $STORAGE_Snapshots_ALL| select-object "id", "subscriptionId", "subscriptionName", "resourceGroup", "snapshotName", "location", "timeCreated", "skuName", "skuTier", "diskSizeInGB", "sourceResourceId", "sourceResourceDiskName", "tags" `
    | Export-CSV "$OutputFolder\WorkbookOutput\Storage\STORAGE_Snapshots_ALL.csv"  -Append -NoTypeInformation
}

############################################################
#################### Networking PAGE #######################
############################################################

# Networking Page -> App Gateways with empty backends
$NETWORKING_AppGateway_Empty_Backend_Query = Search-AzGraph -Query "
resources
| where type =~ 'Microsoft.Network/applicationGateways'
| extend backendPoolsCount = array_length(properties.backendAddressPools), SKUName = tostring(properties.sku.name), SKUTier = tostring(properties.sku.tier),SKUCapacity = properties.sku.capacity, backendPools = properties.backendAddressPools , AppGwId = tostring(id)
| project AppGwId, resourceGroup, subscriptionId, SKUName, SKUTier, SKUCapacity, location, tags
| join (
    resources
    | where type =~ 'Microsoft.Network/applicationGateways'
    | mvexpand backendPools = properties.backendAddressPools
    | extend backendIPCount = array_length(backendPools.properties.backendIPConfigurations)
    | extend backendAddressesCount = array_length(backendPools.properties.backendAddresses)
    | extend backendPoolName  = backendPools.properties.backendAddressPools.name
    | extend AppGwId = tostring(id)
    | summarize backendIPCount = sum(backendIPCount), backendAddressesCount=sum(backendAddressesCount) by AppGwId
) on AppGwId
| project-away AppGwId1
| where  (backendIPCount == 0 or isempty(backendIPCount)) and (backendAddressesCount==0 or isempty(backendAddressesCount))
| extend AppGwName = tostring(split(AppGwId,'providers/Microsoft.Network/applicationGateways/')[1]) 
| join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId 
| order by AppGwId asc
| project AppGwId, AppGwName, SKUName, SKUTier, SKUCapacity, backendIPCount, backendAddressesCount, location, resourceGroup, subscriptionName, subscriptionId, tags
"
foreach ($item in $NETWORKING_AppGateway_Empty_Backend_Query) {
    $NETWORKING_AppGateway_Empty_Backend = New-Object PSObject -Property @{
        AppGwId                = $item.AppGwId;         
        AppGwName              = $item.AppGwName;
        SKUName                = $item.SKUName;
        SKUTier                = $item.SKUTier;
        SKUCapacity            = $item.SKUCapacity;
        backendIPCount         = $item.backendIPCount;
        backendAddressesCount  = $item.backendAddressesCount;
        location               = $item.location; 
        resourceGroup          = $item.resourceGroup;  
        subscriptionName       = $item.subscriptionName; 
        subscriptionId         = $item.subscriptionId;         
        tags                   = $item.tags;                       
        }
    $NETWORKING_AppGateway_Empty_Backend | select-object "AppGwId", "AppGwName", "SKUName", "SKUTier", "SKUCapacity", "backendIPCount", "backendAddressesCount", "location", "resourceGroup", "subscriptionName", "subscriptionId", "tags" `
    | Export-CSV "$OutputFolder\WorkbookOutput\Networking\NETWORKING_AppGateway_Empty_Backend.csv"  -Append -NoTypeInformation
}

# Networking Page -> Load Balancer with empty backends
$NETWORKING_LoadBalancer_Empty_Backend_Query = Search-AzGraph -Query "
resources
| where type =~ 'microsoft.network/loadbalancers'
| where tostring(properties.backendAddressPools) == '[]' 
| join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId 
| project LB_Id = id, LB_Name = name, SKUName = tostring(sku.name), SKUTier = tostring(sku.tier), location, resourceGroup, subscriptionName, subscriptionId, tags
| order by LB_Id asc
"
foreach ($item in $NETWORKING_LoadBalancer_Empty_Backend_Query) {
    $NETWORKING_LoadBalancer_Empty_Backend = New-Object PSObject -Property @{
        LB_Id                  = $item.LB_Id;         
        LB_Name                = $item.LB_Name;
        SKUName                = $item.SKUName;
        SKUTier                = $item.SKUTier;
        location               = $item.location; 
        resourceGroup          = $item.resourceGroup;  
        subscriptionName       = $item.subscriptionName; 
        subscriptionId         = $item.subscriptionId;         
        tags                   = $item.tags;                       
        }
    $NETWORKING_LoadBalancer_Empty_Backend | select-object "LB_Id", "LB_Name", "SKUName", "SKUTier", "location", "resourceGroup", "subscriptionName", "subscriptionId", "tags" `
    | Export-CSV "$OutputFolder\WorkbookOutput\Networking\NETWORKING_LoadBalancer_Empty_Backend.csv"  -Append -NoTypeInformation
}

# Networking Page -> Unattached Public IPs
$NETWORKING_Unattached_Public_IPs_Query = Search-AzGraph -Query "
resources 
| where type =~ 'Microsoft.Network/publicIPAddresses'
| where isempty(properties.ipConfiguration)
| where isempty(properties.natGateway) 
| extend PublicIpId = id, AllocationMethod = tostring(properties.publicIPAllocationMethod), tostring(SKUName = sku.name), SKUTier = tostring(sku.tier)
| join kind=leftouter(
    resources 
    | where type =~ 'microsoft.network/networkinterfaces'
    | where isempty(properties.virtualMachine)
    | where isnull(properties.privateEndpoint)
    | where isnotempty(properties.ipConfigurations) 
    | extend IPconfig = properties.ipConfigurations 
    | mv-expand IPconfig 
    | extend PublicIpId = tostring(IPconfig.properties.publicIPAddress.id)
    | project PublicIpId
) on PublicIpId
| project-away PublicIpId1
| extend PublicIpName = tostring(split(PublicIpId,'providers/Microsoft.Network/publicIPAddresses/')[1]) 
| join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId 
| project PublicIpId, PublicIpName, SKUName, SKUTier, AllocationMethod, zones, location, resourceGroup, subscriptionName, subscriptionId, tags
| order by PublicIpId asc
"
foreach ($item in $NETWORKING_Unattached_Public_IPs_Query) {
    $NETWORKING_Unattached_Public_IPs = New-Object PSObject -Property @{
        PublicIpId             = $item.PublicIpId;         
        PublicIpName           = $item.PublicIpName;
        SKUName                = $item.SKUName;
        SKUTier                = $item.SKUTier;
        AllocationMethod       = $item.AllocationMethod;
        zones                  = $item.zones;
        location               = $item.location; 
        resourceGroup          = $item.resourceGroup;  
        subscriptionName       = $item.subscriptionName; 
        subscriptionId         = $item.subscriptionId;         
        tags                   = $item.tags;                       
        }
    $NETWORKING_Unattached_Public_IPs | select-object "PublicIpId", "PublicIpName", "SKUName", "SKUTier", "AllocationMethod", "zones", "location", "resourceGroup", "subscriptionName", "subscriptionId", "tags" `
    | Export-CSV "$OutputFolder\WorkbookOutput\Networking\NETWORKING_Unattached_Public_IPs.csv"  -Append -NoTypeInformation
}

############################################################
#################### Monitoring PAGE #######################
############################################################

# Monitoring Page -> Log Analytics Workspaces ALL
$MONITORING_Log_Analytics_Workspaces_ALL_Query = Search-AzGraph -Query "
resources
| where type =~ 'microsoft.operationalinsights/workspaces'
| extend state = trim(' ', tostring(properties.provisioningState)), sku = trim(' ', tostring(properties.sku.name)), skuUpdate = trim(' ', tostring(properties.sku.lastSkuUpdate)), retentionDays = toint(properties.retentionInDays), dailyquotaGB  = trim(' ', tostring(properties.workspaceCapping.dailyQuotaGb))
| extend dailyquotaGB = iif(dailyquotaGB !=-1.0, dailyquotaGB,'--')
| extend WorkspaceName = name
| join kind=inner (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId 
| project WorkspaceId = id, WorkspaceName, retentionDays, dailyquotaGB, sku, location, resourceGroup, subscriptionName, subscriptionId, tags
| order by WorkspaceId asc
"
foreach ($item in $MONITORING_Log_Analytics_Workspaces_ALL_Query) {
    $MONITORING_Log_Analytics_Workspaces_ALL = New-Object PSObject -Property @{
        WorkspaceId            = $item.WorkspaceId;         
        WorkspaceName          = $item.WorkspaceName;
        retentionDays          = $item.retentionDays;
        dailyquotaGB           = $item.dailyquotaGB;
        sku                    = $item.sku;
        location               = $item.location; 
        resourceGroup          = $item.resourceGroup;  
        subscriptionName       = $item.subscriptionName; 
        subscriptionId         = $item.subscriptionId;         
        tags                   = $item.tags;                       
        }
    $MONITORING_Log_Analytics_Workspaces_ALL | select-object "WorkspaceId", "WorkspaceName", "retentionDays", "dailyquotaGB", "sku", "location", "resourceGroup", "subscriptionName", "subscriptionId", "tags" `
    | Export-CSV "$OutputFolder\WorkbookOutput\Monitoring\Workspaces_Usage\MONITORING_Log_Analytics_Workspaces_ALL.csv"  -Append -NoTypeInformation
}

############################################################
#################### Subscripton Info ######################
############################################################

# Identifies Dev/Test Subscriptions 
$SUBSCRIPTIONS_DevTest_Query = Search-AzGraph -Query "
ResourceContainers
| where type =~ 'microsoft.resources/subscriptions'
| where properties.subscriptionPolicies.quotaId =~ 'MSDNDevTest_2014-09-01'
| extend OfferType = properties.subscriptionPolicies.quotaId 
| project name, id, tenantId, OfferType
"
foreach ($item in $SUBSCRIPTIONS_DevTest_Query) {
    $SUBSCRIPTIONS_DevTest = New-Object PSObject -Property @{
        name                   = $item.name;         
        id                     = $item.id;
        tenantId               = $item.tenantId;
        OfferType              = $item.OfferType;                    
        }
    $SUBSCRIPTIONS_DevTest | select-object "name", "id", "tenantId", "OfferType"`
    | Export-CSV "$OutputFolder\Subscriptions\DevTest-Subscriptions.csv" -Append -NoTypeInformation
}

#Identifies ALL Subscriptions
$SUBSCRIPTIONS_ALL_Query = Search-AzGraph -Query "
ResourceContainers
| where type =~ 'microsoft.resources/subscriptions'
| extend OfferType = properties.subscriptionPolicies.quotaId 
| project name, id, tenantId, OfferType
"
foreach ($item in $SUBSCRIPTIONS_ALL_Query) {
    $SUBSCRIPTIONS_ALL = New-Object PSObject -Property @{
        name                   = $item.name;         
        id                     = $item.id;
        tenantId               = $item.tenantId;
        OfferType              = $item.OfferType;                    
        }
    $SUBSCRIPTIONS_ALL | select-object "name", "id", "tenantId", "OfferType"`
    | Export-CSV "$OutputFolder\Subscriptions\ALL-Subscriptions.csv" -Append -NoTypeInformation
}

#Lists Subscriptions with Management Group name (requires -UseTenantScope switch)
$SUBSCRIPTIONS_ManagementGroups_w_Subs_Query = Search-AzGraph -Query "
ResourceContainers
| where type =~ 'microsoft.management/managementgroups'
| project mgname = name
| join kind=leftouter (resourcecontainers 
| where type=~ 'microsoft.resources/subscriptions'
| extend  mgParent = properties.managementGroupAncestorsChain 
| project subscriptionId = tostring(split(id,'/subscriptions/')[1]) , mgname = tostring(mgParent[0].name)) on mgname
| project-away mgname1
| join  (resourcecontainers | where type == 'microsoft.resources/subscriptions' | project subscriptionId, subscriptionName = name) on subscriptionId 
| project-away subscriptionId1
" -UseTenantScope
foreach ($item in $SUBSCRIPTIONS_ManagementGroups_w_Subs_Query) {
    $SUBSCRIPTIONS_ManagementGroups_w_Subs = New-Object PSObject -Property @{
        mgname                   = $item.mgname;         
        SubscriptionId           = $item.SubscriptionId;
        SubscriptionName         = $item.SubscriptionName;                  
        }
    $SUBSCRIPTIONS_ManagementGroups_w_Subs | select-object "mgname", "SubscriptionId", "SubscriptionName"`
    | Export-CSV "$OutputFolder\Subscriptions\Subscriptions_with_ManagementGroups.csv" -Append -NoTypeInformation
}

#Count of subscriptions by Management Group (requires -UseTenantScope switch)
$SUBSCRIPTIONS_ManagementGroups_Sub_Count_Query = Search-AzGraph -Query "
ResourceContainers
| where type =~ 'microsoft.management/managementgroups'
| project mgname = name
| join kind=leftouter (resourcecontainers | where type=~ 'microsoft.resources/subscriptions'
| extend  mgParent = properties.managementGroupAncestorsChain | project id, mgname = tostring(mgParent[0].name)) on mgname
| summarize count() by mgname
" -UseTenantScope
foreach ($item in $SUBSCRIPTIONS_ManagementGroups_Sub_Count_Query) {
    $SUBSCRIPTIONS_ManagementGroups_Sub_Count = New-Object PSObject -Property @{
        mgname                   = $item.mgname;         
        count_                   = $item.count_;               
        }
    $SUBSCRIPTIONS_ManagementGroups_Sub_Count | select-object "mgname", "count_"`
    | Export-CSV "$OutputFolder\Subscriptions\ManagementGroups_SubscriptionCount.csv" -Append -NoTypeInformation
}




