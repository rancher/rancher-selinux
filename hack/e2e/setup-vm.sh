#!/bin/bash

set -euxo pipefail

HELM_VERSION="v3.17.3"
HELM_SHA256_amd64="ee88b3c851ae6466a3de507f7be73fe94d54cbf2987cbaa3d1a3832ea331f2cd"
HELM_SHA256_arm64="7944e3defd386c76fd92d9e6fec5c2d65a323f6fadc19bfb5e704e3eee10348e"

KUBECTL_VERSION="v1.35.3"
KUBECTL_SHA256_amd64="fd31c7d7129260e608f6faf92d5984c3267ad0b5ead3bced2fe125686e286ad6"
KUBECTL_SHA256_arm64="6f0cd088a82dde5d5807122056069e2fac4ed447cc518efc055547ae46525f14"

INSTALL_RKE2_VERSION="v1.35.3+rke2r1"

function isSUSE(){
    grep -qi "suse" /etc/os-release
}

function verifyPolicyPresence() {
    local pkgs=("rancher-selinux" "rke2-selinux")
    local types=(
        "prom_node_exporter_t"
        "rke2_service_t"
        "rancher_aiagent_container_t"
        "rancher_aimcp_container_t"
    )

    for p in "${pkgs[@]}"; do
        rpm -q "$p" >/dev/null 2>&1 || { echo "ERROR: RPM $p not installed"; return 1; }
        local m="${p%-selinux}"
        semodule -l | grep -w "$m" || { echo "ERROR: Module $m not loaded"; return 1; }
    done

    for t in "${types[@]}"; do
        seinfo -t "$t" >/dev/null 2>&1 || { echo "ERROR: Type $t unknown"; return 1; }
    done

    echo "SELinux policies verified successfully."
    return 0
}

function enforceSELinux(){
    echo "> Check SELinux status"
    # Short circuit if SELinux is not being enforced.
    getenforce | grep -q Enforcing
    # Remove dontaudits from policy for debugging.
    sudo semodule -DB
    if isSUSE; then
        # Install container-selinux rke2-selinux
        sudo zypper -n install container-selinux
        # Install rancher-selinux policy.
        sudo zypper -n install --allow-unsigned-rpm /tmp/rancher-selinux.rpm
    else
        # Install extra kernel modules needed for networking/conntrack (EL10 requirement).
        # See: https://docs.rke2.io/install/requirements#linux
        # We target $(uname -r) to ensure modules match the running kernel and avoid a reboot.
        sudo dnf install "kernel-modules-extra-$(uname -r)" -y
        # Install container-selinux and selinux-policy latest versions.
        sudo dnf install -y container-selinux selinux-policy --best --allowerasing
        # Install rancher-selinux policy.
        sudo dnf install -y /tmp/rancher-selinux.rpm
    fi
}

function installDependencies(){
    echo 'export PATH=$PATH:/usr/local/bin' >> ~/.bashrc
    echo 'export TERM=xterm' >> ~/.bashrc

    if isSUSE; then
        sudo zypper -n install jq git setools-console
    else
        sudo dnf install -y jq git setools policycoreutils-python-utils
    fi

    ARCH=$(uname -m)
    [[ "${ARCH}" == "aarch64" ]] && ARCH="arm64"
    [[ "${ARCH}" == "x86_64" ]] && ARCH="amd64"

    echo "> Installing Helm ${HELM_VERSION}"
    local HELM_SHA256_VAR="HELM_SHA256_${ARCH}"
    local HELM_SHA256="${!HELM_SHA256_VAR}"
    local HELM_FILE="helm-${HELM_VERSION}-linux-${ARCH}.tar.gz"
    curl -fsSLO "https://get.helm.sh/${HELM_FILE}"
    echo "${HELM_SHA256}  ${HELM_FILE}" | sha256sum -c - --strict
    tar xzf "${HELM_FILE}"
    install -o root -g root -m 0755 linux-${ARCH}/helm /usr/local/bin/helm
    rm -rf linux-${ARCH} "${HELM_FILE}"
    helm version

    echo "> Installing kubectl ${KUBECTL_VERSION} for ${ARCH}"
    local KUBECTL_SHA256_VAR="KUBECTL_SHA256_${ARCH}"
    local KUBECTL_SHA256="${!KUBECTL_SHA256_VAR}"
    curl -fsSLO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
    echo "${KUBECTL_SHA256}  kubectl" | sha256sum -c - --strict
    install -o root -g root -m 0755 kubectl /usr/bin/kubectl
    rm -f kubectl
    kubectl version --client=true
}

function installRKE2(){
    echo "> Installing RKE2 ${INSTALL_RKE2_VERSION} for ${ARCH}"
    curl -sfL https://get.rke2.io -o install.sh
    INSTALL_RKE2_VERSION="${INSTALL_RKE2_VERSION}" sh install.sh
    rm -f install.sh
    # RKE2 install script does not install the SELinux policy by default for tumbleweed; manual setup required.
    if isSUSE; then
        sudo zypper -n install rke2-selinux
    fi
    systemctl enable --now rke2-server.service

    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
    echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml" >> ~/.bashrc
    # Making the kubeconfig world-readable, as this is for test purposes only.
    chmod +r /etc/rancher/rke2/rke2.yaml

    kubectl wait --for=create node/$(hostname) --timeout=240s
    kubectl wait "$(kubectl get node -o name | head -n1)" --for=condition=ready --timeout=240s
    kubectl wait --timeout=240s --for=condition=ready -n kube-system pod -l app.kubernetes.io/instance=rke2-coredns
    kubectl wait --timeout=240s --for=condition=ready -n kube-system pod -l app.kubernetes.io/component=controller
}

function installRancher(){
    echo "> Installing Cert Manager"
    helm repo add jetstack https://charts.jetstack.io
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager --create-namespace \
        --set crds.enabled=true
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s

    echo "> Installing Rancher Manager"
    kubectl create namespace cattle-system
    helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
    helm install rancher rancher-latest/rancher \
        --namespace cattle-system \
        --set hostname=rancher.local \
        --set replicas=1 \
        --wait

    # Background processes, such as Fleet deployment need to take place, which may result in intermittent errors.
    # Adding some extra verification, such as rancher-webhook deployment creation.
    kubectl wait --for=condition=ready -n cattle-system pod -l app=rancher --timeout=600s
    kubectl wait --for=create -n cattle-system deployment/rancher-webhook --timeout=240s
    kubectl wait --for=condition=ready -n cattle-system pod -l app=rancher-webhook --timeout=240s
}

# installRancherChart installs a Rancher chart and waits for its workloads to be ready.
#
# Positional arguments:
#   $1  CHART_NAME         Helm release name (also used as the CRD sibling chart name for HTTP repos).
#   $2  NAMESPACE          Target namespace.
#   $3  WORKLOAD_KIND      "daemonset" or "deployment".
#   $4  WORKLOAD_NAMES     Comma-separated list of workload names owned by this chart.
#   $5  POD_LABEL_SELECTOR Label selector used to wait for pod readiness (e.g. "app=foo").
#                          For charts that own multiple workloads with different labels, pass a
#                          comma-separated list (e.g. "app=foo,app=bar"); each is waited on
#                          independently.
#   $6  CHART_REF          Helm chart reference, e.g. "rancher-charts/foo" (HTTP repo) or
#                          "oci://host/path/chart" (OCI registry).
#   $7+ EXTRA_HELM_ARGS    Additional arguments forwarded to `helm upgrade --install`.
#                          MUST include the chart's SELinux flag — the values key differs per chart
#                          (`--set global.seLinux.enabled=true` for rancher-monitoring/logging,
#                          `--set seLinux.enabled=true` for rancher-ai-agent).
#                          For OCI charts pulled without a pinned `--version`, include `--devel`
#                          so Helm resolves to the latest available chart including pre-releases.
#
# CRD sibling charts are installed only for the HTTP `rancher-charts/` source.
function installRancherChart() {
    local CHART_NAME="$1"
    local NAMESPACE="$2"
    local WORKLOAD_KIND="$3"
    local WORKLOAD_NAMES="$4"
    local POD_LABEL_SELECTOR="$5"
    local CHART_REF="$6"
    local EXTRA_HELM_ARGS="${@:7}"

    # Add the HTTP rancher-charts repo (and install a CRD sibling) only when this chart is sourced
    # from it. OCI charts (e.g. rancher-ai-agent) have no -crd sibling chart.
    if [[ "${CHART_REF}" == rancher-charts/* ]]; then
        helm repo add rancher-charts https://charts.rancher.io/ >/dev/null 2>&1 || true

        echo "> Installing CRD chart ${CHART_NAME}-crd in namespace ${NAMESPACE}"
        helm upgrade --install=true \
            --labels=catalog.cattle.io/cluster-repo-name=rancher-charts \
            --namespace="${NAMESPACE}" --timeout=20m0s --wait=true \
            --create-namespace \
            "${CHART_NAME}-crd" "rancher-charts/${CHART_NAME}-crd"
    fi

    echo "> Installing main chart ${CHART_NAME} (${CHART_REF})"
    helm upgrade --install=true \
        --labels=catalog.cattle.io/cluster-repo-name=rancher-charts \
        --namespace="${NAMESPACE}" --timeout=20m0s --wait=true \
        --create-namespace \
        "${CHART_NAME}" "${CHART_REF}" \
        ${EXTRA_HELM_ARGS}

    # Wait for every workload (DaemonSet or Deployment) the chart owns to be created.
    local IFS_BAK="$IFS"; IFS=','
    for w in ${WORKLOAD_NAMES}; do
        kubectl wait --for=create -n "${NAMESPACE}" "${WORKLOAD_KIND}/${w}" --timeout=240s
    done
    # Wait for pod readiness for each provided label selector (supports multi-workload charts
    # whose workloads don't share a single selector).
    for sel in ${POD_LABEL_SELECTOR}; do
        kubectl wait --for=condition=ready -n "${NAMESPACE}" pod -l "${sel}" --timeout=300s
    done
    IFS="$IFS_BAK"
}

function uninstallRancherChart() {
    local CHART_NAME="$1"
    local NAMESPACE="$2"

    echo "> Uninstalling main chart ${CHART_NAME} from namespace ${NAMESPACE}"
    helm uninstall "${CHART_NAME}" -n "${NAMESPACE}" --wait

    # Best-effort CRD chart removal (only present when a -crd sibling was installed).
    if helm status "${CHART_NAME}-crd" -n "${NAMESPACE}" >/dev/null 2>&1; then
        echo "> Uninstalling CRD chart ${CHART_NAME}-crd"
        helm uninstall "${CHART_NAME}-crd" -n "${NAMESPACE}" --wait
    fi

    echo "> Deleting namespace ${NAMESPACE}"
    kubectl delete ns "${NAMESPACE}" --timeout=120s

    # Force-reclaim caches to provide a clean memory slate for the next chart test.
    # This was added to help mitigate time-out issues in e2e.
    sudo sync && echo 3 > /proc/sys/vm/drop_caches
}

# Example: e2eSELinuxVerification "fluentbit" "fluent-bit" "cattle-logging-system" "rke_logreader_t".
function e2eSELinuxVerification(){
    local POD_NAME_PREFIX="$1"
    local CONTAINER_RUNNING_NAME="$2"
    local POD_NAMESPACE="$3"
    local POD_NAME=$(kubectl get pods -n ${POD_NAMESPACE} -o custom-columns=NAME:.metadata.name | grep "${POD_NAME_PREFIX}" | head -n1)
    local CONTAINER_EXPECTED_SLTYPE="$4"
    local CONTAINER_RUNNING_SLTYPE=""

    echo "> Verify the presence of ${CONTAINER_EXPECTED_SLTYPE}"
    if [[ "$(seinfo -t ${CONTAINER_EXPECTED_SLTYPE} | grep -o ${CONTAINER_EXPECTED_SLTYPE})" == "${CONTAINER_EXPECTED_SLTYPE}" ]]; then
        echo "SELinux type is present: ${CONTAINER_EXPECTED_SLTYPE}"
    else
        echo "SELinux type is not present: ${CONTAINER_EXPECTED_SLTYPE}"
    fi

    echo "> Verify expected SELinux context type ${CONTAINER_EXPECTED_SLTYPE} for container ${CONTAINER_RUNNING_NAME} in pod ${POD_NAME}"
    # Get SELinux type from Pod-level securityContext, falling back to Container-level if empty
    CONTAINER_RUNNING_SLTYPE=$(kubectl get pod ${POD_NAME} -n ${POD_NAMESPACE} -o json | jq -r ".spec.securityContext.seLinuxOptions.type // (.spec.containers[] | select(.name==\"${CONTAINER_RUNNING_NAME}\") | .securityContext.seLinuxOptions.type)")
    if [[ "${CONTAINER_RUNNING_SLTYPE}" == "${CONTAINER_EXPECTED_SLTYPE}" ]]; then
        echo "SELinux type is correct: ${CONTAINER_RUNNING_SLTYPE}"
    else
        echo "SELinux type is incorrect or not set: ${CONTAINER_RUNNING_SLTYPE}"
        exit 1
    fi

    echo "> Look for any AVCs related to ${CONTAINER_RUNNING_SLTYPE}"
    if ausearch -m AVC,USER_AVC | grep "${CONTAINER_RUNNING_SLTYPE}" > /dev/null; then
        echo "AVCs found for ${CONTAINER_RUNNING_SLTYPE}"
        ausearch -m AVC,USER_AVC | grep "${CONTAINER_RUNNING_SLTYPE}"
        exit 1
    else
        echo "No AVCs found for ${CONTAINER_RUNNING_SLTYPE}"
    fi
}

function main(){
    enforceSELinux
    installDependencies
    installRKE2
    verifyPolicyPresence
    installRancher

    # Note: Append this list with new components to install and test the rancher-selinux policy.
    #
    # Per-component layout (space-separated):
    #   NAMESPACE WORKLOAD_KIND WORKLOAD_NAMES POD_LABELS VERIFY_TRIPLETS CHART_REF EXTRA_HELM_ARGS
    #
    # - WORKLOAD_KIND:   daemonset|deployment
    # - WORKLOAD_NAMES:  comma-separated list of workload names owned by the chart.
    # - POD_LABELS:      comma-separated list of label selectors used for readiness waits
    #                    (one entry per workload group that doesn't share a common selector).
    # - VERIFY_TRIPLETS: ';'-separated list of 'podNamePrefix:containerName:expected_selinux_type'
    # - CHART_REF:       "rancher-charts/<name>" (HTTP repo) or "oci://host/path/chart" (OCI registry)
    # - EXTRA_HELM_ARGS: forwarded verbatim to `helm upgrade --install`. MUST include the chart's
    #                    SELinux flag (e.g. `--set global.seLinux.enabled=true` or
    #                    `--set seLinux.enabled=true`). For OCI charts without a pinned version,
    #                    include `--devel` so Helm resolves to the latest pre-release.
    declare -A COMPONENTS=(
        [rancher-monitoring]="cattle-monitoring-system daemonset rancher-monitoring-prometheus-node-exporter app.kubernetes.io/name=prometheus-node-exporter node-exporter:node-exporter:prom_node_exporter_t rancher-charts/rancher-monitoring --set global.seLinux.enabled=true --set prometheus-node-exporter.hostRootFsMount.enabled=false"
        [rancher-logging]="cattle-logging-system daemonset rancher-logging-root-fluentbit app.kubernetes.io/name=fluentbit fluentbit:fluent-bit:rke_logreader_t rancher-charts/rancher-logging --set global.seLinux.enabled=true"
        [rancher-ai-agent]="cattle-ai-agent-system deployment rancher-ai-agent,rancher-mcp-server app=rancher-ai-agent,app=rancher-mcp-server rancher-ai-agent:agent:rancher_aiagent_container_t;rancher-mcp-server:mcp-server:rancher_aimcp_container_t oci://stgregistry.suse.com/rancher/charts/rancher-ai-agent --devel --set seLinux.enabled=true --set insecureSkipTls=true"
    )

    for CHART_NAME in "${!COMPONENTS[@]}"; do
        # Read the space-separated values into individual variables.
        read -r NAMESPACE WORKLOAD_KIND WORKLOAD_NAMES POD_LABELS VERIFY_TRIPLETS CHART_REF EXTRA_HELM_ARGS <<< "${COMPONENTS[${CHART_NAME}]}"

        echo "> Installing and testing Chart: ${CHART_NAME} in Namespace: ${NAMESPACE}"

        # 1. Install the chart.
        installRancherChart \
            "${CHART_NAME}" \
            "${NAMESPACE}" \
            "${WORKLOAD_KIND}" \
            "${WORKLOAD_NAMES}" \
            "${POD_LABELS}" \
            "${CHART_REF}" \
            "${EXTRA_HELM_ARGS}"

        # 2. Run E2E SELinux verification for every (podPrefix,container,type) triplet.
        IFS_BAK="$IFS"; IFS=';'
        for triplet in ${VERIFY_TRIPLETS}; do
            IFS=':' read -r POD_PREFIX C_NAME C_TYPE <<< "${triplet}"
            echo "> Verifying pod ${POD_PREFIX} / container ${C_NAME} against SELinux type ${C_TYPE}"
            e2eSELinuxVerification "${POD_PREFIX}" "${C_NAME}" "${NAMESPACE}" "${C_TYPE}"
        done
        IFS="$IFS_BAK"

        # 3. Uninstall the chart (free some resources).
        uninstallRancherChart \
            "${CHART_NAME}" \
            "${NAMESPACE}"
    done
}

# Rocky does not include this in the PATH by default, which is required for Helm.
export PATH=$PATH:/usr/local/bin

main
