#!/usr/bin/env bash
# TUB Azure demo -- STANDALONE CLEANUP for the Traffic Manager Linked Records demo.
# Self-contained: rediscovers resources by TAG, so it works days later even after
# Cloud Shell has forgotten the original variables. Just set SUBSCRIPTION + RG.
#
# It finds every resource tagged demo=tm-linked-records in the RG and deletes in
# the SAFE order that respects linked-record deletion protection:
#   RECORDS (in each tagged zone) -> PROFILES -> PUBLIC IPs -> ZONES (last).
# Deleting the zone before its linked records orphans the profile's reference
# counter (a preview bug), so records always go first and zones always go last.
set -uo pipefail

### ---- EDIT THESE TWO ----
SUBSCRIPTION="YOUR_SUBSCRIPTION_ID"
RG="YOUR_RG_NAME"
### ------------------------

# Tag family to clean. To wipe ONE specific run instead of all demo runs, set
# TAG_QUERY to "demoRun=<suffix>" (the suffix printed by the setup script).
TAG_QUERY="demo=tm-linked-records"

az account set --subscription "$SUBSCRIPTION"

echo "Discovering resources tagged '$TAG_QUERY' in RG '$RG'..."

# Discover taggable resources by type (filter the tag query down to this RG).
ZONES=$(az resource list --tag $TAG_QUERY \
  --query "[?resourceGroup=='$RG' && type=='Microsoft.Network/dnszones'].name" -o tsv)
PROFILES=$(az resource list --tag $TAG_QUERY \
  --query "[?resourceGroup=='$RG' && type=='Microsoft.Network/trafficmanagerprofiles'].name" -o tsv)
PIPS=$(az resource list --tag $TAG_QUERY \
  --query "[?resourceGroup=='$RG' && type=='Microsoft.Network/publicIPAddresses'].name" -o tsv)

echo "Zones:    ${ZONES:-<none>}"
echo "Profiles: ${PROFILES:-<none>}"
echo "Public IPs: ${PIPS:-<none>}"

# 1) RECORDS FIRST -- delete A and CNAME record sets in each tagged zone.
#    (Record sets are not taggable; we enumerate them from the tagged zone.)
#    This releases the deletion-protection hold that linked records place on
#    their Traffic Manager profiles.
for Z in $ZONES; do
  echo ">> Clearing linked record sets in zone: $Z"
  for R in $(az network dns record-set a list -g "$RG" -z "$Z" --query "[].name" -o tsv); do
    echo "   delete A record: $R"
    az network dns record-set a delete -g "$RG" -z "$Z" -n "$R" -y
  done
  for R in $(az network dns record-set cname list -g "$RG" -z "$Z" --query "[].name" -o tsv); do
    echo "   delete CNAME record: $R"
    az network dns record-set cname delete -g "$RG" -z "$Z" -n "$R" -y
  done
done

# 2) PROFILES -- now unreferenced, so deletion protection is released.
for P in $PROFILES; do
  echo ">> Deleting Traffic Manager profile: $P"
  az network traffic-manager profile delete -g "$RG" -n "$P"
done

# 3) PUBLIC IPs
for I in $PIPS; do
  echo ">> Deleting public IP: $I"
  az network public-ip delete -g "$RG" -n "$I"
done

# 4) ZONES LAST -- after their records and the profiles are gone.
for Z in $ZONES; do
  echo ">> Deleting DNS zone: $Z"
  az network dns zone delete -g "$RG" -n "$Z" -y
done

echo "Cleanup complete. Verify with:"
echo "  az resource list --tag $TAG_QUERY --query \"[?resourceGroup=='$RG'].name\" -o tsv"
