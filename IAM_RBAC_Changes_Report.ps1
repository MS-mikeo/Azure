============================================================================================

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

============================================================================================

# This script will retrieve all Azure RBAC Role Assignments in IAM from the Activity Logs for the set amount of days & then provide the information in a user-friendly readable format. 

# Set Amount of days to look back for assignments
$days=7
# Connecting to Azure AD to lookup users, groups, and SPNs
connect-azuread
# Gathering role assignments for set amount of previous days
$logs=Get-AzLog -StartTime (Get-Date).AddDays(-$days) | Where-Object {$_.Authorization.Action -like 'Microsoft.Authorization/roleAssignments/*'} 
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
		$RoleDefinitionId=($RoleDefinitionIdFULL.split('/'))[4]				
		$RoleDefinitionName=""
		$RoleDefinitionName=(get-azroledefinition -Id $RoleDefinitionId).Name				
		# Clearing Variables
                $Username=""
                $Groupname=""
                    if(($table.Properties.PrincipalType -eq "User")) 
                      {
                        # Getting User                        
                        $Username=(get-azureaduser -objectid $PrincipalId | select-object UserPrincipalName).UserPrincipalName
                        # Output
                        write-host "Operation Id: " $log.OperationId
                        write-host "Event Timestamp: " $log.EventTimestamp
                        write-host "Operation Name: " $log.OperationName
                        write-host "Status: " $log.Status
                        write-host "Event Initiated by: " $log.Caller
			write-host "Role Definition Id:" $RoleDefinitionId
			write-host "Role Definition Name:" $RoleDefinitionName
                        write-host "Object type given permissions:" $table.Properties.PrincipalType
                        write-host "Object Id given permissions:" $PrincipalId
                        write-host "User given permissions:" $Username
                        write-host "Scope: " $log.Authorization.Scope
                        write-host " "                        
                        }  
                          if(($table.Properties.PrincipalType -eq "ServicePrincipal"))
                          {                
                          # Getting SPN
                          $SPNname=""
                          $SPNname=(Get-AzureADServicePrincipal -objectid $PrincipalId | select-object Displayname).DisplayName
                          # Output
                          write-host "Operation Id: " $log.OperationId
                          write-host "Event Timestamp: " $log.EventTimestamp
                          write-host "Operation Name: " $log.OperationName
                          write-host "Status: " $log.Status
                          write-host "Event Initiated by: " $log.Caller
			  write-host "Role Definition Id:" $RoleDefinitionId
			  write-host "Role Definition Name:" $RoleDefinitionName
                          write-host "Object type given permissions:" $table.Properties.PrincipalType
                          write-host "Object Id given permissions:" $PrincipalId
                          write-host "SPN given permissions:" $SPNname
                          write-host " "
                          }
                              if(($table.Properties.PrincipalType -eq "Group"))
                              {                
                              # Getting Group
                              $Groupname=""
                              $Groupname=(get-azureadgroup -objectid $PrincipalId | select-object Displayname).DisplayName
                              # Output
                              write-host "Operation Id: " $log.OperationId
                              write-host "Event Timestamp: " $log.EventTimestamp
                              write-host "Operation Name: " $log.OperationName
                              write-host "Status: " $log.Status
                              write-host "Event Initiated by: " $log.Caller
			      write-host "Role Definition Id:" $RoleDefinitionId
			      write-host "Role Definition Name:" $RoleDefinitionName
                              write-host "Object type given permissions:" $table.Properties.PrincipalType
                              write-host "Object Id given permissions:" $PrincipalId
                              write-host "Group given permissions:" $Groupname
                              write-host " "
                              }
                }
                Else 
                 {
                   write-host "Operation Id: " $log.OperationId
                   write-host "Event Timestamp: " $log.EventTimestamp
                   write-host "Operation Name: " $log.OperationName
                   write-host "Status: " $log.Status
                   write-host "Event Initiated by: " $log.Caller
                   write-host "Object type given permissions: N/A" 
                   write-host "Object type Id permissions: N/A"
                   write-host "User/Group/ServicePrincipal given permissions: N/A"
                   write-host "Scope: " $log.Authorization.Scope
                   write-host
                   write-host " "
                   }
$log=""
}

