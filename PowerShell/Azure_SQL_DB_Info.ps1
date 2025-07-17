<#
.SYNOPSIS
    Get Azure SQL Database size information and backup metrics over the last 30 days

.DESCRIPTION
    This script retrieves information about Azure SQL Databases including:
    - Database size metrics (current, max, average over 30 days)
    - Backup storage metrics from Azure platform metrics
    - Full backup, log backup, and differential backup storage metrics

.PARAMETER SubscriptionId
    Azure Subscription ID to query

.PARAMETER TenantId
    Optional: Azure Tenant ID to use for authentication

.PARAMETER ResourceGroupName
    Optional: Specific Resource Group to query (if not specified, all resource groups will be queried)

.PARAMETER ServerName
    Optional: Specific SQL Server to query (if not specified, all servers will be queried)

.PARAMETER DatabaseName
    Optional: Specific Database to query (if not specified, all databases will be queried)

.EXAMPLE
    .\Azure_SQL_DB_Info.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012"

.EXAMPLE
    .\Azure_SQL_DB_Info.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -TenantId "87654321-4321-4321-4321-210987654321"

.EXAMPLE
    .\Azure_SQL_DB_Info.ps1 -SubscriptionId "12345678-1234-1234-1234-123456789012" -ResourceGroupName "MyRG" -ServerName "MyServer"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $false)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$ServerName,
    
    [Parameter(Mandatory = $false)]
    [string]$DatabaseName
)

# Import required modules
$requiredModules = @('Az.Accounts', 'Az.Sql', 'Az.Monitor')
foreach ($module in $requiredModules) {
    if (!(Get-Module -ListAvailable -Name $module)) {
        Write-Host "Installing module: $module" -ForegroundColor Yellow
        Install-Module -Name $module -Force -AllowClobber -Scope CurrentUser
    }
    Import-Module -Name $module -Force
}

# Function to authenticate to Azure
function Connect-ToAzure {
    Write-Host "Connecting to Azure..." -ForegroundColor Green
    try {
        $context = Get-AzContext
        if (!$context) {
            if ($TenantId) {
                Connect-AzAccount -TenantId $TenantId
            } else {
                Connect-AzAccount
            }
        }
        $context = Set-AzContext -SubscriptionId $SubscriptionId
        
        # Display connection information
        Write-Host "Successfully connected to Azure:" -ForegroundColor Green
        Write-Host "  Subscription ID: $($context.Subscription.Id)" -ForegroundColor White
        Write-Host "  Subscription Name: $($context.Subscription.Name)" -ForegroundColor White
        Write-Host "  Tenant ID: $($context.Tenant.Id)" -ForegroundColor White
        Write-Host "  Account: $($context.Account.Id)" -ForegroundColor White
    }
    catch {
        Write-Error "Failed to connect to Azure: $_"
        exit 1
    }
}

# Function to get backup metrics with optimized time grain
function Get-BackupMetric {
    param(
        [string]$ResourceId,
        [string]$MetricName,
        [datetime]$StartTime,
        [datetime]$EndTime,
        [string]$DatabaseName,
        [string]$MetricType
    )
    
    Write-Verbose "Attempting to get $MetricType metrics for $DatabaseName"
    
    # Use only the working time grain (1 day) for backup metrics
    try {
        Write-Verbose "  Querying with 1-day time grain..."
        $metrics = Get-AzMetric -ResourceId $ResourceId -MetricName $MetricName -StartTime $StartTime -EndTime $EndTime -TimeGrain "1.00:00:00" -ErrorAction Stop
        
        if ($metrics -and $metrics.Data -and $metrics.Data.Count -gt 0) {
            Write-Verbose "  Found $($metrics.Data.Count) data points"
            
            $maxValue = 0
            foreach ($dataPoint in $metrics.Data) {
                # Check all possible value types
                $values = @($dataPoint.Maximum, $dataPoint.Average, $dataPoint.Total, $dataPoint.Minimum)
                foreach ($value in $values) {
                    if ($value -and $value -gt $maxValue) {
                        $maxValue = $value
                    }
                }
            }
            
            if ($maxValue -gt 0) {
                $resultGB = [math]::Round($maxValue / 1GB, 2)
                Write-Verbose "  $MetricType size: $resultGB GB"
                return $resultGB
            } else {
                Write-Verbose "  $MetricType size is 0 or null"
                return 0
            }
        } else {
            Write-Verbose "  No $MetricType metric data found"
            return 0
        }
    }
    catch {
        $errorMsg = $_.Exception.Message
        Write-Verbose "  $MetricType metrics failed - Error: $errorMsg"
        
        # Check for specific error types
        if ($errorMsg -like "*BadRequest*") {
            Write-Verbose "  BadRequest error - metric may not be supported for this database tier"
        } elseif ($errorMsg -like "*NotFound*") {
            Write-Verbose "  NotFound error - metric definition may not exist"
        }
        
        Write-Warning "$MetricType metrics not available for $DatabaseName - may not be supported for this database service tier"
        return "N/A"
    }
}

# Function to get available metrics for debugging
function Get-AvailableMetrics {
    param(
        [string]$ResourceId
    )
    
    try {
        Write-Host "    Checking available metrics..." -ForegroundColor Gray
        $availableMetrics = Get-AzMetricDefinition -ResourceId $ResourceId
        
        # Show backup-related metrics
        $backupMetrics = $availableMetrics | Where-Object { $_.Name.Value -like "*backup*" }
        if ($backupMetrics) {
            Write-Host "    Available backup metrics:" -ForegroundColor Gray
            foreach ($metric in $backupMetrics) {
                Write-Host "      - $($metric.Name.Value) ($($metric.Name.LocalizedValue)) - Unit: $($metric.Unit)" -ForegroundColor Gray
            }
        }
        
        # Show storage-related metrics
        $storageMetrics = $availableMetrics | Where-Object { $_.Name.Value -like "*storage*" }
        if ($storageMetrics) {
            Write-Host "    Available storage metrics:" -ForegroundColor Gray
            foreach ($metric in $storageMetrics) {
                Write-Host "      - $($metric.Name.Value) ($($metric.Name.LocalizedValue)) - Unit: $($metric.Unit)" -ForegroundColor Gray
            }
        }
        
        if (!$backupMetrics -and !$storageMetrics) {
            Write-Host "    No backup or storage metrics found for this database" -ForegroundColor Yellow
            Write-Host "    Total available metrics: $($availableMetrics.Count)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "    Could not retrieve metric definitions: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Function to get database metrics from Azure Monitor
function Get-DatabaseMetrics {
    param(
        [string]$ResourceGroupName,
        [string]$ServerName,
        [string]$DatabaseName
    )
    
    $endTime = Get-Date
    $startTime = $endTime.AddDays(-30)
    
    try {
        # Get database information
        $database = Get-AzSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $ServerName -DatabaseName $DatabaseName
        $resourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Sql/servers/$ServerName/databases/$DatabaseName"
        
        Write-Verbose "Getting metrics for database: $DatabaseName"
        
        # Debug: Check available metrics
        Get-AvailableMetrics -ResourceId $resourceId
        
        # Initialize results object
        $result = @{
            SubscriptionName = (Get-AzContext).Subscription.Name
            ResourceGroup = $ResourceGroupName
            ServerName = $ServerName
            DatabaseName = $DatabaseName
            Location = $database.Location
            AppID = if ($database.Tags -and $database.Tags.ContainsKey("AppID")) { $database.Tags["AppID"] } else { "N/A" }
            Edition = $database.Edition
            ServiceObjective = $database.CurrentServiceObjectiveName
            SkuName = if ($database.SkuName) { $database.SkuName } else { "N/A" }
            Family = if ($database.Family) { $database.Family } else { "N/A" }
            Status = $database.Status
            DatabaseSizeGB = "N/A"  # Will be populated from storage metrics
            CurrentBackupStorageRedundancy = $database.CurrentBackupStorageRedundancy
        }
        
        # Get actual used storage metrics (not max allocated)
        try {
            Write-Verbose "  Getting actual storage usage..."
            $storageMetrics = Get-AzMetric -ResourceId $resourceId -MetricName "storage" -StartTime $startTime -EndTime $endTime -TimeGrain "1.00:00:00" -ErrorAction Stop
            
            if ($storageMetrics -and $storageMetrics.Data -and $storageMetrics.Data.Count -gt 0) {
                Write-Verbose "  Found $($storageMetrics.Data.Count) storage data points"
                
                # Get the most recent storage usage value
                $latestDataPoint = $storageMetrics.Data | Sort-Object TimeStamp | Select-Object -Last 1
                $storageValue = $latestDataPoint.Average
                
                if (!$storageValue) {
                    $storageValue = $latestDataPoint.Maximum
                }
                if (!$storageValue) {
                    $storageValue = $latestDataPoint.Total
                }
                
                if ($storageValue -and $storageValue -gt 0) {
                    $result.DatabaseSizeGB = [math]::Round($storageValue / 1GB, 2)
                    Write-Verbose "  Current storage used: $($result.DatabaseSizeGB) GB"
                } else {
                    $result.DatabaseSizeGB = 0
                    Write-Verbose "  Storage usage is 0 or null"
                }
            } else {
                Write-Verbose "  No storage metric data found"
                $result.DatabaseSizeGB = "N/A"
            }
        }
        catch {
            Write-Verbose "  Storage metrics not available for $DatabaseName - Error: $($_.Exception.Message)"
            $result.DatabaseSizeGB = "N/A"
        }
        
        # Get backup storage metrics - removed as per user request
        
        # Get full backup size metrics
        $result.MaxFullBackupSizeGB = Get-BackupMetric -ResourceId $resourceId -MetricName "full_backup_size_bytes" -StartTime $startTime -EndTime $endTime -DatabaseName $DatabaseName -MetricType "Full backup"
        
        # Get log backup size metrics
        $result.MaxLogBackupSizeGB = Get-BackupMetric -ResourceId $resourceId -MetricName "log_backup_size_bytes" -StartTime $startTime -EndTime $endTime -DatabaseName $DatabaseName -MetricType "Log backup"
        
        # Get differential backup size metrics
        $result.MaxDiffBackupSizeGB = Get-BackupMetric -ResourceId $resourceId -MetricName "diff_backup_size_bytes" -StartTime $startTime -EndTime $endTime -DatabaseName $DatabaseName -MetricType "Differential backup"
        
        return $result
    }
    catch {
        Write-Warning "Failed to get metrics for database $DatabaseName on server $ServerName : $_"
        return $null
    }
}

# Main execution
try {
    Write-Host "Starting Azure SQL Database Information Collection" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    
    # Connect to Azure
    Connect-ToAzure
    
    # Get SQL Servers
    $servers = @()
    if ($ResourceGroupName -and $ServerName) {
        $servers = @(Get-AzSqlServer -ResourceGroupName $ResourceGroupName -ServerName $ServerName)
    }
    elseif ($ResourceGroupName) {
        $servers = Get-AzSqlServer -ResourceGroupName $ResourceGroupName
    }
    elseif ($ServerName) {
        # Get all resource groups and find the server
        $allRGs = Get-AzResourceGroup
        foreach ($rg in $allRGs) {
            try {
                $server = Get-AzSqlServer -ResourceGroupName $rg.ResourceGroupName -ServerName $ServerName -ErrorAction SilentlyContinue
                if ($server) {
                    $servers += $server
                    break
                }
            }
            catch {
                # Continue if server not found in this RG
            }
        }
    }
    else {
        # Get all SQL servers in the subscription
        $allRGs = Get-AzResourceGroup
        foreach ($rg in $allRGs) {
            try {
                $rgServers = Get-AzSqlServer -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
                $servers += $rgServers
            }
            catch {
                # Continue if no servers in this RG
            }
        }
    }
    
    if ($servers.Count -eq 0) {
        Write-Warning "No SQL servers found with the specified criteria"
        exit 1
    }
    
    $allResults = @()
    
    foreach ($server in $servers) {
        Write-Host "Processing server: $($server.ServerName)" -ForegroundColor Green
        
        # Get databases
        $databases = @()
        if ($DatabaseName) {
            try {
                $databases = @(Get-AzSqlDatabase -ResourceGroupName $server.ResourceGroupName -ServerName $server.ServerName -DatabaseName $DatabaseName)
            }
            catch {
                Write-Warning "Database $DatabaseName not found on server $($server.ServerName)"
                continue
            }
        }
        else {
            $databases = Get-AzSqlDatabase -ResourceGroupName $server.ResourceGroupName -ServerName $server.ServerName | Where-Object { $_.DatabaseName -ne "master" }
        }
        
        foreach ($db in $databases) {
            Write-Host "  Processing database: $($db.DatabaseName)" -ForegroundColor Yellow
            
            # Get all database metrics with verbose output
            $VerbosePreference = "Continue"  # Enable verbose output temporarily
            $metrics = Get-DatabaseMetrics -ResourceGroupName $server.ResourceGroupName -ServerName $server.ServerName -DatabaseName $db.DatabaseName
            $VerbosePreference = "SilentlyContinue"  # Reset verbose output
            
            if ($metrics) {
                $allResults += New-Object PSObject -Property $metrics
            }
        }
    }
    
    # Display results
    Write-Host "`nDatabase Size Information (Actual Used Storage):" -ForegroundColor Cyan
    Write-Host "===============================================" -ForegroundColor Cyan
    
    $allResults | Format-Table -AutoSize -Property SubscriptionName, ResourceGroup, ServerName, DatabaseName, Location, AppID, Edition, ServiceObjective, SkuName, Family, Status, DatabaseSizeGB, CurrentBackupStorageRedundancy
    
    # Display backup information
    Write-Host "`nBackup Size Information (Last 30 Days):" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    
    $allResults | Format-Table -AutoSize -Property SubscriptionName, ResourceGroup, ServerName, DatabaseName, MaxFullBackupSizeGB, MaxLogBackupSizeGB, MaxDiffBackupSizeGB
    
    # Export to CSV with specific column order
    $csvPath = "Azure_SQL_DB_Info_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $allResults | Select-Object SubscriptionName, ResourceGroup, ServerName, DatabaseName, Location, AppID, Edition, ServiceObjective, SkuName, Family, Status, DatabaseSizeGB, CurrentBackupStorageRedundancy, MaxFullBackupSizeGB, MaxLogBackupSizeGB, MaxDiffBackupSizeGB | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "Results exported to: $csvPath" -ForegroundColor Green
    
    # Display summary
    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host "========" -ForegroundColor Cyan
    Write-Host "Total Servers: $($servers.Count)"
    Write-Host "Total Databases: $($allResults.Count)"
    
    $totalDatabaseStorage = ($allResults | Where-Object { $_.DatabaseSizeGB -ne "N/A" } | Measure-Object -Property DatabaseSizeGB -Sum).Sum
    $totalFullBackups = ($allResults | Where-Object { $_.MaxFullBackupSizeGB -ne "N/A" } | Measure-Object -Property MaxFullBackupSizeGB -Sum).Sum
    
    Write-Host "Total Database Storage Used: $([math]::Round($totalDatabaseStorage, 2)) GB"
    Write-Host "Total Full Backup Storage: $([math]::Round($totalFullBackups, 2)) GB"
    
    # Display breakdown by location
    Write-Host "`nBreakdown by Location:" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    
    $locationSummary = $allResults | Group-Object Location | Sort-Object Name
    foreach ($location in $locationSummary) {
        $locationStorage = ($location.Group | Where-Object { $_.DatabaseSizeGB -ne "N/A" } | Measure-Object -Property DatabaseSizeGB -Sum).Sum
        $locationBackups = ($location.Group | Where-Object { $_.MaxFullBackupSizeGB -ne "N/A" } | Measure-Object -Property MaxFullBackupSizeGB -Sum).Sum
        
        Write-Host "Location: $($location.Name)" -ForegroundColor Yellow
        Write-Host "  Databases: $($location.Count)"
        Write-Host "  Storage Used: $([math]::Round($locationStorage, 2)) GB"
        Write-Host "  Full Backup Storage: $([math]::Round($locationBackups, 2)) GB"
        Write-Host ""
    }
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
}

Write-Host "`nScript completed successfully!" -ForegroundColor Green
