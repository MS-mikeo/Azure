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

ZONE="tubdemo-${SFX}.com"          # zone name: not global, but randomized to avoid confusion
TM_OLD="tm-old-${SFX}"             # old-way TM profile (globally unique)
TM_NEW="tm-new-${SFX}"             # new-way TM profile (globally unique)
BACKEND_IP="203.0.113.10"          # RFC 5737 TEST-NET-3: reserved for docs/demos, never routes
PIP_APP="tubapp-${SFX}"            # Public IP w/ DNS label -> a REAL resolvable FQDN for the CNAME endpoint (label unique per region)

echo "Suffix for this run: $SFX"

# 0) Private DNS-hosted public zone (authoritative on Azure name servers even
#    without registrar delegation -- we'll query those NS directly).
az network dns zone create -g "$RG" -n "$ZONE"
NS=$(az network dns zone show -g "$RG" -n "$ZONE" --query "nameServers[0]" -o tsv)
echo "Azure DNS name server for this zone: $NS"

# ============================================================
# OLD WAY: Traffic Manager profile + a CNAME that points at
# <profile>.trafficmanager.net. Client sees the extra CNAME hop.
# ============================================================
az network traffic-manager profile create -g "$RG" -n "$TM_OLD" \
  --routing-method Priority --unique-dns-name "$TM_OLD" \
  --ttl 30 --protocol HTTP --port 80 --path "/"
az network traffic-manager endpoint create -g "$RG" --profile-name "$TM_OLD" \
  -n ep1 --type externalEndpoints --target "$BACKEND_IP" --priority 1 --endpoint-status Enabled

# The old-school record: a manual CNAME to the trafficmanager.net FQDN
az network dns record-set cname set-record -g "$RG" -z "$ZONE" \
  -n app-old --cname "${TM_OLD}.trafficmanager.net"

# ============================================================
# NEW WAY: Traffic Manager Linked Record (CNAME type). A CNAME record set
# links directly to the TM profile via --tm-profile. Azure DNS flattens ->
# returns the endpoint FQDN directly, with NO trafficmanager.net hop.
# Strictly Typed Profile: a CNAME record requires a CNAME-typed TM profile
# whose endpoints are FQDNs (not IPs) -- hence the Public IP + DNS label below.
# ============================================================
# Lightweight real FQDN for the endpoint: a Public IP + DNS label (no compute).
az network public-ip create -g "$RG" -n "$PIP_APP" --sku Standard \
  --dns-name "$PIP_APP" --allocation-method Static
APP_FQDN=$(az network public-ip show -g "$RG" -n "$PIP_APP" --query "dnsSettings.fqdn" -o tsv)
echo "App FQDN (CNAME endpoint target): $APP_FQDN"

az network traffic-manager profile create -g "$RG" -n "$TM_NEW" \
  --routing-method Priority --unique-dns-name "$TM_NEW" \
  --record-type CNAME \
  --ttl 30 --protocol HTTP --port 80 --path "/"
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

# ============================================================
# CLEANUP  -- ORDER MATTERS (verified)
# A linked record puts DELETION PROTECTION on the NEW Traffic Manager profile:
# the profile can't be deleted while a DNS record set still references it.
# Delete in this order: RECORDS -> PROFILES -> PUBLIC IP -> ZONE (last).
# WARNING: do NOT delete the zone before its linked records. Doing so orphans
# the profile's reference counter (a preview bug: ParentResourceNotFound on the
# records + the profile still reports itself "referenced"). Recovery if you hit
# it: recreate the same-named zone + the linked record(s) with --tm-profile,
# then run this block in order.
# ============================================================
# 1) Records first (releases the deletion-protection hold on the profiles)
az network dns record-set cname delete -g "$RG" -z "$ZONE" -n app-new -y
az network dns record-set cname delete -g "$RG" -z "$ZONE" -n app-old -y
# 2) Traffic Manager profiles (now unreferenced)
az network traffic-manager profile delete -g "$RG" -n "$TM_OLD"
az network traffic-manager profile delete -g "$RG" -n "$TM_NEW"
# 3) Public IP
az network public-ip delete -g "$RG" -n "$PIP_APP"
# 4) Zone LAST
az network dns zone delete -g "$RG" -n "$ZONE" -y
# ============================================================
