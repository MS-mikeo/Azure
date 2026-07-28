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

#Requires -Modules Az.Accounts
<#
.SYNOPSIS
    Pulls dimension-preserved token usage metrics for every Azure OpenAI / Foundry
    resource in the tenant and exports a flat CSV for Power BI cost attribution.

.DESCRIPTION
    Uses the Azure Monitor Metrics REST API (NOT diagnostic-settings -> Log Analytics),
    so the ModelDeploymentName / ModelName dimensions are PRESERVED instead of being
    flattened/aggregated the way AzureMetrics diagnostic export does.

    Resources are enumerated once via Azure Resource Graph, so a single scheduled run
    covers the whole estate rather than a per-resource manual pull.

.NOTES
    Auth: run Connect-AzAccount first (interactive) or run under an automation identity.
    MCA billing: join the output CSV to your exported price sheet on model/meter in Power BI
    to derive cost = (prompt/1000)*inputPrice + (generated/1000)*outputPrice.
    Metric names: ProcessedPromptTokens (input), GeneratedTokens (output),
    ProcessedInferenceTokens (total). See monitor-openai-reference.
#>

[CmdletBinding()]
param(
    [string[]] $SubscriptionId,                          # optional: limit to specific subscriptions
    [datetime] $StartTime = (Get-Date).AddDays(-30),
    [datetime] $EndTime   = (Get-Date),
    [string]   $Interval  = 'P1D',                        # ISO-8601 granularity (P1D = daily, PT1H = hourly)
    [string]   $OutputCsv = './foundry-token-usage.csv',
    [switch]   $Discover                                  # diagnostic: report EVERY token counter's non-zero total, then exit
)

$ErrorActionPreference = 'Stop'

# --- 1. Enumerate Azure OpenAI + Foundry (AIServices) accounts via Resource Graph ---
$argQuery = @'
resources
| where type =~ 'microsoft.cognitiveservices/accounts'
| where kind in~ ('OpenAI','AIServices')
| extend CostCenter = coalesce(tostring(tags['CostCenter']), tostring(tags['costcenter']), tostring(tags['Cost Center']))
| project id, name, kind, location, resourceGroup, subscriptionId, CostCenter
'@

$argBody = @{ query = $argQuery }
if ($SubscriptionId) { $argBody.subscriptions = $SubscriptionId }

$argResp = Invoke-AzRestMethod -Method POST `
    -Uri 'https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2022-10-01' `
    -Payload ($argBody | ConvertTo-Json -Depth 5)

$resources = ($argResp.Content | ConvertFrom-Json).data
Write-Host "Found $($resources.Count) Azure OpenAI / Foundry resource(s)."

$timespan = '{0:o}/{1:o}' -f $StartTime.ToUniversalTime(), $EndTime.ToUniversalTime()

# --- 1b. DISCOVERY MODE ---------------------------------------------------------
# Querying the ACTUAL total for every
# token counter each resource emits (not just the one input/output pair the export picks).
# Daily interval keeps the call light over long windows. Prints per-metric totals, exits.
if ($Discover) {
    $discInterval = 'P1D'
    Write-Host "`n=== DISCOVERY: non-zero token totals per resource ($($StartTime.ToString('yyyy-MM-dd')) -> $($EndTime.ToString('yyyy-MM-dd'))) ===`n"
    foreach ($r in $resources) {
        $defResp = Invoke-AzRestMethod -Method GET -Uri "https://management.azure.com$($r.id)/providers/microsoft.insights/metricDefinitions?api-version=2024-02-01"
        if ($defResp.StatusCode -ne 200) { Write-Warning "$($r.name): metricDefinitions HTTP $($defResp.StatusCode)"; continue }
        $defs       = $defResp.Content | ConvertFrom-Json
        $tokenNames = @($defs.value | Where-Object { $_.name.value -match 'Token' } | ForEach-Object { $_.name.value } | Sort-Object -Unique)

        Write-Host "$($r.name)  [$($r.kind)]  $($r.location)"
        if (-not $tokenNames) { Write-Host '    (emits no token metrics at all)'; continue }

        $any = $false
        # Batch metric names (<=15/request) to stay under the API's metricnames cap.
        for ($i = 0; $i -lt $tokenNames.Count; $i += 15) {
            $chunk = $tokenNames[$i..([math]::Min($i + 14, $tokenNames.Count - 1))]
            $mUri  = "https://management.azure.com$($r.id)/providers/microsoft.insights/metrics" +
                     "?api-version=2024-02-01&metricnames=$($chunk -join ',')&aggregation=Total&interval=$discInterval&timespan=$timespan"
            $mResp = Invoke-AzRestMethod -Method GET -Uri $mUri
            if ($mResp.StatusCode -ne 200) { Write-Warning "    metrics HTTP $($mResp.StatusCode): $($mResp.Content)"; continue }
            foreach ($metric in ($mResp.Content | ConvertFrom-Json).value) {
                $sum = 0.0
                foreach ($ts in $metric.timeseries) { foreach ($p in $ts.data) { if ($p.total) { $sum += $p.total } } }
                if ($sum -gt 0) { $any = $true; Write-Host ('    {0,-28} {1,15:N0}' -f $metric.name.value, $sum) }
            }
        }
        if (-not $any) { Write-Host '    (no non-zero token metrics in window)' }
    }
    Write-Host "`nDiscovery complete. Note: serverless/MaaS models under a hub-based Foundry PROJECT report under"
    Write-Host "Microsoft.MachineLearningServices/workspaces and are NOT enumerated here."
    return
}

# --- 2. Pull token metrics per resource, split by deployment + model ---
# Metric names & dimensions differ between kinds (OpenAI vs AIServices/Foundry) and change
# over time. Instead of hard-coding, DISCOVER the token metrics each resource actually emits
# via metricDefinitions, then query only those with a supported aggregation + dimension.
$rows = [System.Collections.Generic.List[object]]::new()

foreach ($r in $resources) {
    # 2a. Discover metric definitions for this resource
    $defUri = "https://management.azure.com$($r.id)/providers/microsoft.insights/metricDefinitions?api-version=2024-02-01"
    try {
        $defs = (Invoke-AzRestMethod -Method GET -Uri $defUri).Content | ConvertFrom-Json
    }
    catch {
        Write-Warning "metricDefinitions failed for $($r.name): $_"
        continue
    }

    $tokenDefs = @($defs.value | Where-Object { $_.name.value -match 'Token' })
    if ($tokenDefs.Count -eq 0) {
        $available = ($defs.value.name.value | Sort-Object -Unique) -join ', '
        Write-Warning "$($r.name): no token metrics emitted. Available metrics: $available"
        continue
    }

    # 2b. Pick ONE input + ONE output token counter that this resource emits.
    #     Prefer the newer Foundry names (InputTokens/OutputTokens); fall back to the classic
    #     Azure OpenAI names (ProcessedPromptTokens/GeneratedTokens). Querying every token
    #     metric would (a) exceed the ~20 metricnames/request cap and (b) double-count.
    $emitted      = @($defs.value.name.value)
    $inputMetric  = @('InputTokens','ProcessedPromptTokens') | Where-Object { $emitted -contains $_ } | Select-Object -First 1
    $outputMetric = @('OutputTokens','GeneratedTokens')      | Where-Object { $emitted -contains $_ } | Select-Object -First 1
    $pick = @($inputMetric, $outputMetric | Where-Object { $_ })
    $pick = @($pick | Where-Object { $_ } | Select-Object -Unique)
    if ($pick.Count -eq 0) {
        Write-Warning "$($r.name): no input/output token counter found. Token metrics: $(($tokenDefs.name.value) -join ', ')"
        continue
    }

    # Direction lookup for the CSV (Input vs Output)
    $direction = @{}
    if ($inputMetric)  { $direction[$inputMetric]  = 'Input' }
    if ($outputMetric) { $direction[$outputMetric] = 'Output' }

    # Does this resource expose the ModelDeploymentName dimension on the picked metrics?
    $pickDefs     = @($defs.value | Where-Object { $pick -contains $_.name.value })
    $dimNames     = @($pickDefs.dimensions.value | Sort-Object -Unique)
    $hasDeployDim = $dimNames -contains 'ModelDeploymentName'

    $metricNames = $pick -join ','
    $uri = "https://management.azure.com$($r.id)/providers/microsoft.insights/metrics" +
           "?api-version=2024-02-01" +
           "&metricnames=$metricNames" +
           "&aggregation=Total" +
           "&interval=$Interval" +
           "&timespan=$timespan"
    if ($hasDeployDim) {
        $uri += "&`$filter=" + [uri]::EscapeDataString("ModelDeploymentName eq '*' and ModelName eq '*'")
    }

    # Invoke-AzRestMethod does NOT throw on HTTP 4xx/5xx — check the status explicitly.
    $resp = Invoke-AzRestMethod -Method GET -Uri $uri
    if ($resp.StatusCode -ne 200) {
        Write-Warning "$($r.name): metrics HTTP $($resp.StatusCode): $($resp.Content)"
        continue
    }
    $body = $resp.Content | ConvertFrom-Json

    $before = $rows.Count
    foreach ($metric in $body.value) {
        $metricName = $metric.name.value
        foreach ($ts in $metric.timeseries) {
            $dims = @{}
            foreach ($mv in $ts.metadatavalues) { $dims[$mv.name.value] = $mv.value }
            foreach ($point in $ts.data) {
                $value = $point.total
                if ($null -eq $value -or $value -eq 0) { continue }
                $rows.Add([pscustomobject]@{
                    TimeStamp           = $point.timeStamp
                    SubscriptionId      = $r.subscriptionId
                    ResourceGroup       = $r.resourceGroup
                    Resource            = $r.name
                    Location            = $r.location
                    CostCenter          = $r.CostCenter
                    Kind                = $r.kind
                    ModelDeploymentName = $dims['ModelDeploymentName']
                    ModelName           = $dims['ModelName']
                    Metric              = $metricName
                    Direction           = $direction[$metricName]
                    Tokens              = $value
                })
            }
        }
    }
    $added = $rows.Count - $before
    if ($added -eq 0) {
        Write-Host "  $($r.name): [$metricNames] returned 0 non-zero points in window (no inference in range?)."
    } else {
        Write-Host "  $($r.name): +$added rows."
    }
}

# --- 3. Export flat CSV for Power BI ---
$rows | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding utf8
Write-Host "Exported $($rows.Count) rows to $OutputCsv"
