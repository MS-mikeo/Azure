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
BACKEND_IP="203.0.113.10"           # a stand-in "app" IP the TM endpoints return

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
# NEW WAY: Traffic Manager Linked Record. A record set links directly
# to the TM profile via --tm-profile. Azure DNS flattens -> returns IPs.
# Strictly Typed Profile: an A record requires an A-typed TM profile.
# ============================================================
az network traffic-manager profile create -g "$RG" -n "$TM_NEW" \
  --routing-method Priority --unique-dns-name "$TM_NEW" \
  --record-type A \
  --ttl 30 --protocol HTTP --port 80 --path "/"
az network traffic-manager endpoint create -g "$RG" --profile-name "$TM_NEW" \
  -n ep1 --type externalEndpoints --target "$BACKEND_IP" --priority 1 --endpoint-status Enabled

TM_NEW_ID=$(az network traffic-manager profile show -g "$RG" -n "$TM_NEW" --query id -o tsv)

# Link the A record set directly to the profile (the PREVIEW feature)
az network dns record-set a create -g "$RG" -z "$ZONE" -n app-new \
  --tm-profile "$TM_NEW_ID"

# ============================================================
# DEMO: query the zone's Azure DNS name server directly (no delegation needed)
# ============================================================
echo ""
echo "=================== OLD WAY (CNAME hop) ==================="
echo ">>> nslookup app-old.$ZONE  (watch for the trafficmanager.net CNAME)"
nslookup -type=A "app-old.$ZONE" "$NS" || true
echo ""
echo "=================== NEW WAY (linked record / flattened) ==================="
echo ">>> nslookup app-new.$ZONE  (IP returned directly, NO trafficmanager.net)"
nslookup -type=A "app-new.$ZONE" "$NS" || true

# ============================================================
# CLEANUP
# az network dns zone delete -g "$RG" -n "$ZONE" -y
# az network traffic-manager profile delete -g "$RG" -n "$TM_OLD"
# az network traffic-manager profile delete -g "$RG" -n "$TM_NEW"
# ============================================================
