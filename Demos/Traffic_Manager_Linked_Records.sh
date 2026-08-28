# Demo: Azure Traffic Manager Linked Records
# https://learn.microsoft.com/azure/dns/dns-traffic-manager-linked-records
# Shows OLD way (CNAME hop to trafficmanager.net) vs NEW way (linked record, IPs returned directly, no trafficmanager.net on the wire).
# Run in Azure Cloud Shell (Bash). Feature/property is in PREVIEW.

### ---- EDIT THESE TWO ----
SUBSCRIPTION="YOUR_SUBSCRIPTION_ID"
RG="YOUR_RG_NAME"
### ------------------------

az account set --subscription "$SUBSCRIPTION"

# Random suffix so MANY people can deploy in parallel tenants without collisions.
# CRITICAL: Traffic Manager --unique-dns-name is GLOBALLY unique across all Azure.
SFX=$(tr -dc 'a-z0-9' </dev/urandom | head -c 6)

# Tags applied to every taggable resource so a SEPARATE cleanup script can
# rediscover them later (Cloud Shell won't remember these variables days later).
# NOTE: DNS record sets are NOT taggable -- cleanup finds the tagged ZONE and
# lists its record sets. demoRun lets you clean one run; demo cleans the family.
TAGS="demo=tm-linked-records demoRun=${SFX}"

ZONE="tubdemo-${SFX}.com"          # zone name: not global, but randomized to avoid confusion
TM_OLD="tm-old-${SFX}"             # old-way TM profile (globally unique)
TM_NEW="tm-new-${SFX}"             # new-way TM profile (globally unique)
PIP_APP="tubapp-${SFX}"            # Public IP w/ DNS label -> a REAL resolvable FQDN, used as the endpoint target for BOTH profiles (label unique per region)

echo "Suffix for this run: $SFX"

# 0) Private DNS-hosted public zone (authoritative on Azure name servers even
#    without registrar delegation -- we'll query those NS directly).
az network dns zone create -g "$RG" -n "$ZONE" --tags $TAGS
NS=$(az network dns zone show -g "$RG" -n "$ZONE" --query "nameServers[0]" -o tsv)
echo "Azure DNS name server for this zone: $NS"

# Lightweight real FQDN (no compute): a Public IP + DNS label. Used as the
# endpoint target for BOTH profiles so nothing points at a dead placeholder IP.
az network public-ip create -g "$RG" -n "$PIP_APP" --sku Standard \
  --dns-name "$PIP_APP" --allocation-method Static --tags $TAGS
APP_FQDN=$(az network public-ip show -g "$RG" -n "$PIP_APP" --query "dnsSettings.fqdn" -o tsv)
echo "App FQDN (endpoint target): $APP_FQDN"

# ============================================================
# OLD WAY: Traffic Manager profile + a CNAME that points at
# <profile>.trafficmanager.net. Client sees the extra CNAME hop.
# ============================================================
az network traffic-manager profile create -g "$RG" -n "$TM_OLD" \
  --routing-method Priority --unique-dns-name "$TM_OLD" \
  --ttl 30 --protocol HTTP --port 80 --path "/" --tags $TAGS
az network traffic-manager endpoint create -g "$RG" --profile-name "$TM_OLD" \
  -n ep1 --type externalEndpoints --target "$APP_FQDN" --priority 1 --endpoint-status Enabled

# The old-school record: a manual CNAME to the trafficmanager.net FQDN
az network dns record-set cname set-record -g "$RG" -z "$ZONE" \
  -n app-old --cname "${TM_OLD}.trafficmanager.net"

# ============================================================
# NEW WAY: Traffic Manager Linked Record (CNAME type). A CNAME record set
# links directly to the TM profile via --tm-profile. Azure DNS flattens ->
# returns the endpoint FQDN directly, with NO trafficmanager.net hop.
# Strictly Typed Profile: a CNAME record requires a CNAME-typed TM profile
# whose endpoints are FQDNs (not IPs) -- we reuse the Public IP FQDN above.
# ============================================================
az network traffic-manager profile create -g "$RG" -n "$TM_NEW" \
  --routing-method Priority --unique-dns-name "$TM_NEW" \
  --record-type CNAME \
  --ttl 30 --protocol HTTP --port 80 --path "/" --tags $TAGS
az network traffic-manager endpoint create -g "$RG" --profile-name "$TM_NEW" \
  -n ep1 --type externalEndpoints --target "$APP_FQDN" --priority 1 --endpoint-status Enabled

TM_NEW_ID=$(az network traffic-manager profile show -g "$RG" -n "$TM_NEW" --query id -o tsv)

# Link the CNAME record set directly to the profile (the PREVIEW feature)
az network dns record-set cname create -g "$RG" -z "$ZONE" -n app-new \
  --tm-profile "$TM_NEW_ID"

# ============================================================
# DEMO: query the zone's Azure DNS name server directly (no delegation needed)
# ============================================================
echo ""
echo "=================== OLD WAY (CNAME hop) ==================="
echo ">>> nslookup app-old.$ZONE  (canonical name shows *.trafficmanager.net)"
nslookup -type=CNAME "app-old.$ZONE" "$NS" || true
echo ""
echo "=================== NEW WAY (linked record / flattened) ==================="
echo ">>> nslookup app-new.$ZONE  (canonical name is YOUR app FQDN, NO trafficmanager.net)"
nslookup -type=CNAME "app-new.$ZONE" "$NS" || true
