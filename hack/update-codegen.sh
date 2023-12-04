#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail

SCRIPT_ROOT="$(dirname "${BASH_SOURCE[0]}")/.."

get_latest_release() {
  curl --silent "https://api.github.com/repos/kubernetes-sigs/controller-tools/releases/latest" |
  grep '"tag_name":' |
  sed -E 's/.*"([^"]+)".*/\1/'
}

# Get latest tagged release of controller-gen
LATEST_CONTROLLER_GEN_VER=$(get_latest_release)

if ( ! ( command -v controller-gen > /dev/null )  || test "$(controller-gen --version)" != "Version: ${LATEST_CONTROLLER_GEN_VER}" ); then
  echo "controller-gen not found or out-of-date, installing latest version sigs.k8s.io/controller-tools@${LATEST_CONTROLLER_GEN_VER}"
  olddir="${PWD}"
  builddir="$(mktemp -d)"
  cd "${builddir}"
  GO111MODULE=on go install sigs.k8s.io/controller-tools/cmd/controller-gen@${LATEST_CONTROLLER_GEN_VER}
  cd "${olddir}"
  if [[ "${builddir}" == /tmp/* ]]; then #paranoia
      rm -rf "${builddir}"
  fi
fi

bash "${SCRIPT_ROOT}/vendor/k8s.io/code-generator/kube_codegen.sh" deepcopy \
  github.com/openshift/openshift-network-operator/pkg/generated github.com/openshift/cluster-network-operator/pkg/apis \
  "network:v1" \
  --go-header-file "${SCRIPT_ROOT}/hack/custom-boilerplate.go.txt"


echo "Generating CRDs"
mkdir -p _output/crds
controller-gen crd paths=./pkg/apis/... output:crd:dir=_output/crds

# ensure our CRD is installed by setting a "release profile"
RELEASE_PROFILE="include.release.openshift.io/self-managed-high-availability=true"
ROKS_PROFILE="include.release.openshift.io/ibm-cloud-managed=true"
SINGLE_NODE_DEV_PROFILE="include.release.openshift.io/single-node-developer=true"
HEADER="# This file is automatically generated. DO NOT EDIT"

# Add a new CRD? Duplicate these lines
echo "${HEADER}" > manifests/0000_70_cluster-network-operator_01_pki_crd.yaml
oc annotate --local -o yaml \
  "${RELEASE_PROFILE}" \
  "${ROKS_PROFILE}" \
  "${SINGLE_NODE_DEV_PROFILE}" \
  -f _output/crds/network.operator.openshift.io_operatorpkis.yaml >> manifests/0000_70_cluster-network-operator_01_pki_crd.yaml

# and also the CRD from library-go
oc annotate --local -o yaml --overwrite \
  "${RELEASE_PROFILE}" \
  "${ROKS_PROFILE}" \
  -f vendor/github.com/openshift/api/operator/v1/0000_70_cluster-network-operator_01-Default.crd.yaml > manifests/0000_70_cluster-network-operator_01-Default.crd.yaml

oc annotate --local -o yaml --overwrite \
  "${RELEASE_PROFILE}" \
  "${ROKS_PROFILE}" \
  -f vendor/github.com/openshift/api/operator/v1/0000_70_cluster-network-operator_01-CustomNoUpgrade.crd.yaml > manifests/0000_70_cluster-network-operator_01-CustomNoUpgrade.crd.yaml

oc annotate --local -o yaml --overwrite \
  "${RELEASE_PROFILE}" \
  "${ROKS_PROFILE}" \
  -f vendor/github.com/openshift/api/operator/v1/0000_70_cluster-network-operator_01-TechPreviewNoUpgrade.crd.yaml > manifests/0000_70_cluster-network-operator_01-TechPreviewNoUpgrade.crd.yaml

echo "${HEADER}" > manifests/0000_70_cluster-network-operator_01_egr_crd.yaml
oc annotate --local -o yaml --overwrite \
  "${RELEASE_PROFILE}" \
  "${ROKS_PROFILE}" \
  "${SINGLE_NODE_DEV_PROFILE}" \
  -f vendor/github.com/openshift/api/networkoperator/v1/001-egressrouter.crd.yaml >> manifests/0000_70_cluster-network-operator_01_egr_crd.yaml

echo "${HEADER}" > bindata/cloud-network-config-controller/001-crd.yaml
cat vendor/github.com/openshift/api/cloudnetwork/v1/001-cloudprivateipconfig.crd.yaml >> bindata/cloud-network-config-controller/001-crd.yaml
