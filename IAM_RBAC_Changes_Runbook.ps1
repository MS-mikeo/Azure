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

# This script will retrieve all Azure RBAC Role Assignments in IAM from the Activity Logs for the set amount of days & then provide the information in a user-friendly readable format. 
# Version 2.0 Updated on 10/11/2023 by MikeO
#	- Fixed split for Role Definition to account for Custom Roles (10/11/2023)
#	- Fixed split to get Entity (10/11/2023)
#	- Migrated commands to use Microsoft Graph Powershell SDK (10/11/2023)
#	- Added loop through all supscriptions that are available to the logged in identity 
#	- Removed all write-host and setup output for automation
#	- Added the check to correlate successful events & remove entries that do not add value to the reporting
#	- Added the friendly name lookup for the Role Definition and the cleaned up Entity field 
#
# Open Issues: Management Groups Activity Logs are not able to be queried (10/11/2023)

# Runbook will need the following Powershell Modules installed: Az.Accounts (or Az), Microsoft.Graph.Authentication, Microsoft.Graph.Application, Microsoft.Graph.Users, Microsoft.Graph.Groups

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

# Connect to Azure with user-assigned managed identity
$AzureContext = (Connect-AzAccount -Identity -AccountId <User Assigned Managed Identity Client ID>).context

# set and store context
$AzureContext = Set-AzContext -Subscription <subscription id> -DefaultProfile $AzureContext

# Connecting to Azure AD to lookup users, groups, and SPNs
Connect-MgGraph -Scopes "User.Read.All", "Group.Read.All", "Application.Read.All"
Connect-AzAccount

# Set Amount of days to look back for assignments
$days=7

#Setting CSV File name
$filename="RBAC_Change_Report.csv"

#Setting up array to catch all Output from each loop
$RBAC_Change_Log=@()

# Getting list of subscriptions to loop through for Activity Log retrieval
$subscriptions=get-azsubscription
foreach ($subscription in $subscriptions) 
{
set-azcontext -Subscription $subscription.Id 
# Gathering role assignments for set amount of previous days, correlated with object IDs for successful events to avoid confusion
$SuccessLogs=""
$Logs=@()
$SuccessLogs=Get-AzLog -StartTime (Get-Date).AddDays(-$days) | Where-Object {$_.Authorization.Action -like 'Microsoft.Authorization/roleAssignments/*' `
-and $_.Status -eq "Succeeded"}  
foreach ($SuccessLog in $SuccessLogs) 
	{
	$logs+=Get-AzLog -StartTime (Get-Date).AddDays(-$days) | Where-Object {$_.Authorization.Action -like 'Microsoft.Authorization/roleAssignments/*' `
 	-and $_.OperationId -eq $SuccessLog.OperationId -and $_.Status -ne "Succeeded"} 
	}
foreach ($Log in $Logs) 
              {
              # Extracting nested properties -> requestbody to a table to extract Principal ID & Type
              $nestedproperties=""
              $nestedproperties=@($log.Properties.Content)
	          # If nestedproperties contains data, extracting the data into friendly output
              if(($nestedproperties.requestbody -ne $null)) 
                {
		            # Setting up the table
                $table=""
                $table=$nestedproperties.requestbody | convertfrom-json
                # Getting Principal Id
                $PrincipalId=""
                $PrincipalId=$table.Properties.PrincipalId
	        #Getting Role Definition ID and Name in friendly format
	        $RoleDefinitionIdFULL=""
		$RoleDefinitionIdFULL=$table.Properties.RoleDefinitionId
	        $RoleDefinitionId=""
	        $RoleDefinitionId=($RoleDefinitionIdFULL -split ('/providers/Microsoft.Authorization/roleDefinitions/'))[1]		
		$RoleDefinitionName=""
		$RoleDefinitionName=(get-azroledefinition -Id $RoleDefinitionId).Name
  	        # Getting the entity (object) that the pemissions were applied to
    		$Entity=($nestedproperties.entity -split ('/providers/Microsoft.Authorization/roleAssignments/'))[0]
                if(($table.Properties.PrincipalType -eq "User")) 
                      {
                      # Getting User Info
		      $User=""
                      $User=get-mguser -userid $PrincipalId
                      # Output
                      $RBAC_Change_Log += New-Object PSCustomObject -Property @{
                      "OperationId" = $log.OperationId;
               	      "EventTimestamp" = $log.EventTimestamp;
		      "OperationName" = $log.OperationName;
    		      "Status" = $log.Status;
       		      "InitiatedBy_Caller" = $log.Caller;
	  	      "RoleDefinitionId" = $RoleDefinitionId;
	 	      "RoleDefinitionName" = $RoleDefinitionName;	
	  	      "Entity" = $Entity;
                      "Scope" = $log.Authorization.Scope;
     		      "PrincipalType" = $table.Properties.PrincipalType;
		      "Added_ID" = $User.UserPrincipalName;
		      "Added_ID_DisplayName" = $User.DisplayName;
               	       }
                       }  
                          if(($table.Properties.PrincipalType -eq "ServicePrincipal"))
                          	{                
                          	# Getting SPN Info                        
                          	$SPN=""
                          	$SPN=Get-MGServicePrincipal -ServicePrincipalId $PrincipalId
                          	# Output
                		$RBAC_Change_Log += New-Object PSCustomObject -Property @{
                		"OperationId" = $log.OperationId;
               		        "EventTimestamp" = $log.EventTimestamp;
		 	        "OperationName" = $log.OperationName;
    			        "Status" = $log.Status;
       			        "InitiatedBy_Caller" = $log.Caller;
	    		        "RoleDefinitionId" = $RoleDefinitionId;
	 		        "RoleDefinitionName" = $RoleDefinitionName;	
	  		        "Entity" = $Entity;
                         	"Scope" = $log.Authorization.Scope;
     			        "PrincipalType" = $table.Properties.PrincipalType;
			        "Added_ID" = $SPN.Id;
			        "Added_ID_DisplayName" = $SPN.DisplayName;
     			  	}
                                }
                                	if(($table.Properties.PrincipalType -eq "Group"))
                              			{                
                              			# Getting Group Info
                              			$Group=""
                              			$Group=get-mggroup -groupid $PrincipalId
                              			# Output
                             			$RBAC_Change_Log += New-Object PSCustomObject -Property @{
                	         		"OperationId" = $log.OperationId;
               		         		"EventTimestamp" = $log.EventTimestamp;
		 	                        "OperationName" = $log.OperationName;
    			                  	"Status" = $log.Status;
       			                	"InitiatedBy_Caller" = $log.Caller;
	    		                  	"RoleDefinitionId" = $RoleDefinitionId;
	 		                        "RoleDefinitionName" = $RoleDefinitionName;	
	  		                        "Entity" = $Entity;
                            			"Scope" = $log.Authorization.Scope;
     			                  	"PrincipalType" = $table.Properties.PrincipalType;
			                        "Added_ID" = $Group.Id;
			                        "Added_ID_DisplayName" = $Group.DisplayName;
	                      	                }
                               }
	                }
           }
}                      

$RBAC_Change_Log | Select-Object "OperationId","EventTimestamp","OperationName","Status","InitiatedBy_Caller","RoleDefinitionId", `
"RoleDefinitionName","Entity","Scope","PrincipalType","Added_ID","Added_ID_DisplayName" `
| Sort-Object "Scope","RoleDefinitionName","PrincipalType","Added_ID_DisplayName"  | Export-CSV $Filename -Notype
