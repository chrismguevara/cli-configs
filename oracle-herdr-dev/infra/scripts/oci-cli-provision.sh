#!/usr/bin/env bash
# Provision the same VM as infra/terraform with the OCI CLI instead of Terraform.
# Idempotency is by display name: each step looks the object up before creating it.
#
# Prerequisites: `oci setup config` done (~/.oci/config), and these variables:
#   OCI_COMPARTMENT_OCID   compartment (the tenancy OCID for the root compartment)
#   SSH_PUBLIC_KEY_FILE    e.g. ~/.ssh/id_ed25519.pub
# Optional:
#   SHAPE (VM.Standard.A1.Flex) SHAPE_OCPUS (4) SHAPE_MEMORY_GB (24)
#   BOOT_VOLUME_GB (100) AD_INDEX (0) NAME (ol9-herdr-dev) SSH_SOURCE_CIDR (0.0.0.0/0)
set -euo pipefail

: "${OCI_COMPARTMENT_OCID:?set OCI_COMPARTMENT_OCID}"
: "${SSH_PUBLIC_KEY_FILE:?set SSH_PUBLIC_KEY_FILE}"
NAME="${NAME:-ol9-herdr-dev}"
SHAPE="${SHAPE:-VM.Standard.A1.Flex}"
SHAPE_OCPUS="${SHAPE_OCPUS:-4}"
SHAPE_MEMORY_GB="${SHAPE_MEMORY_GB:-24}"
BOOT_VOLUME_GB="${BOOT_VOLUME_GB:-100}"
AD_INDEX="${AD_INDEX:-0}"
SSH_SOURCE_CIDR="${SSH_SOURCE_CIDR:-0.0.0.0/0}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
C="${OCI_COMPARTMENT_OCID}"

log() { printf '\033[1;34m==> %s\033[0m\n' "$*"; }

command -v oci >/dev/null || { echo "oci CLI not found: https://docs.oracle.com/iaas/Content/API/SDKDocs/cliinstall.htm" >&2; exit 1; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }

log "availability domain"
AD="$(oci iam availability-domain list --compartment-id "${C}" | jq -r ".data[${AD_INDEX}].name")"
echo "    ${AD}"

log "vcn"
VCN="$(oci network vcn list --compartment-id "${C}" --display-name "${NAME}-vcn" | jq -r '.data[0].id // empty')"
if [[ -z "${VCN}" ]]; then
  VCN="$(oci network vcn create --compartment-id "${C}" --display-name "${NAME}-vcn" --cidr-blocks '["10.42.0.0/16"]' --dns-label devvcn --wait-for-state AVAILABLE | jq -r '.data.id')"
fi
echo "    ${VCN}"

log "internet gateway"
IGW="$(oci network internet-gateway list --compartment-id "${C}" --vcn-id "${VCN}" --display-name "${NAME}-igw" | jq -r '.data[0].id // empty')"
if [[ -z "${IGW}" ]]; then
  IGW="$(oci network internet-gateway create --compartment-id "${C}" --vcn-id "${VCN}" --display-name "${NAME}-igw" --is-enabled true --wait-for-state AVAILABLE | jq -r '.data.id')"
fi
echo "    ${IGW}"

log "route table"
RT="$(oci network route-table list --compartment-id "${C}" --vcn-id "${VCN}" --display-name "${NAME}-rt" | jq -r '.data[0].id // empty')"
if [[ -z "${RT}" ]]; then
  RT="$(oci network route-table create --compartment-id "${C}" --vcn-id "${VCN}" --display-name "${NAME}-rt" \
    --route-rules "[{\"destination\":\"0.0.0.0/0\",\"destinationType\":\"CIDR_BLOCK\",\"networkEntityId\":\"${IGW}\"}]" \
    --wait-for-state AVAILABLE | jq -r '.data.id')"
fi
echo "    ${RT}"

log "security list (ingress tcp/22 only)"
SL="$(oci network security-list list --compartment-id "${C}" --vcn-id "${VCN}" --display-name "${NAME}-ssh-only" | jq -r '.data[0].id // empty')"
if [[ -z "${SL}" ]]; then
  SL="$(oci network security-list create --compartment-id "${C}" --vcn-id "${VCN}" --display-name "${NAME}-ssh-only" \
    --egress-security-rules '[{"destination":"0.0.0.0/0","destinationType":"CIDR_BLOCK","protocol":"all","isStateless":false}]' \
    --ingress-security-rules "[{\"source\":\"${SSH_SOURCE_CIDR}\",\"sourceType\":\"CIDR_BLOCK\",\"protocol\":\"6\",\"isStateless\":false,\"tcpOptions\":{\"destinationPortRange\":{\"min\":22,\"max\":22}}},{\"source\":\"0.0.0.0/0\",\"sourceType\":\"CIDR_BLOCK\",\"protocol\":\"1\",\"isStateless\":false,\"icmpOptions\":{\"type\":3,\"code\":4}}]" \
    --wait-for-state AVAILABLE | jq -r '.data.id')"
fi
echo "    ${SL}"

log "subnet"
SUBNET="$(oci network subnet list --compartment-id "${C}" --vcn-id "${VCN}" --display-name "${NAME}-subnet" | jq -r '.data[0].id // empty')"
if [[ -z "${SUBNET}" ]]; then
  SUBNET="$(oci network subnet create --compartment-id "${C}" --vcn-id "${VCN}" --display-name "${NAME}-subnet" \
    --cidr-block 10.42.1.0/24 --dns-label dev --route-table-id "${RT}" --security-list-ids "[\"${SL}\"]" \
    --prohibit-public-ip-on-vnic false --wait-for-state AVAILABLE | jq -r '.data.id')"
fi
echo "    ${SUBNET}"

log "image (latest Oracle Linux 9 for ${SHAPE})"
IMAGE="$(oci compute image list --compartment-id "${C}" --operating-system "Oracle Linux" --operating-system-version 9 --shape "${SHAPE}" --sort-by TIMECREATED --sort-order DESC | jq -r '.data[0].id')"
echo "    ${IMAGE}"

log "instance ${NAME}"
INSTANCE="$(oci compute instance list --compartment-id "${C}" --display-name "${NAME}" --lifecycle-state RUNNING | jq -r '.data[0].id // empty')"
if [[ -z "${INSTANCE}" ]]; then
  shape_args=()
  if [[ "${SHAPE}" == *Flex ]]; then
    shape_args=(--shape-config "{\"ocpus\":${SHAPE_OCPUS},\"memoryInGBs\":${SHAPE_MEMORY_GB}}")
  fi
  INSTANCE="$(oci compute instance launch --compartment-id "${C}" --availability-domain "${AD}" --display-name "${NAME}" \
    --shape "${SHAPE}" "${shape_args[@]}" \
    --image-id "${IMAGE}" --boot-volume-size-in-gbs "${BOOT_VOLUME_GB}" \
    --subnet-id "${SUBNET}" --assign-public-ip true --hostname-label dev \
    --ssh-authorized-keys-file "${SSH_PUBLIC_KEY_FILE}" \
    --user-data-file "${HERE}/../terraform/cloud-init.yaml" \
    --wait-for-state RUNNING | jq -r '.data.id')"
fi
echo "    ${INSTANCE}"

IP="$(oci compute instance list-vnics --instance-id "${INSTANCE}" | jq -r '.data[0]."public-ip"')"
log "done"
echo "ssh -L 5173:localhost:5173 -L 8081:localhost:8081 -L 8181:localhost:8181 -L 5433:localhost:5433 opc@${IP}"
