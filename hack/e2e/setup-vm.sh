#!/bin/bash

set -euxo pipefail

function enforceSELinux(){
    echo "> Check SELinux status"
    # Short circuit if SELinux is not being enforced.
    getenforce | grep -q Enforcing
    # Remove dontaudits from policy for debugging
    sudo semodule -DB 
    # Install rancher-selinux policy
    sudo dnf install -y /tmp/rancher-selinux.rpm
}

function installDependencies(){
    echo 'echo "export PATH=$PATH:/usr/local/bin"' >> ~/.bashrc
    echo 'echo "export TERM=xterm"' >> ~/.bashrc

    echo "> Installing Helm 3"
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    helm version

    local KUBECTL_VERSION
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    ARCH=$(uname -p)
    [[ "${ARCH}" == "aarch64" ]] && ARCH="arm64"
    [[ "${ARCH}" == "x86_64" ]] && ARCH="amd64"

    echo "> Installing kubectl ${KUBECTL_VERSION} for ${ARCH}"
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl.sha256"
    echo "$(<kubectl.sha256)  kubectl" | sha256sum -c -
    install -o root -g root -m 0755 kubectl /usr/bin/kubectl
    kubectl version --client=true
}

function installRKE2(){
    echo "> Installing RKE2"
    curl -sfL https://get.rke2.io | sh -
    systemctl start rke2-server.service
    systemctl enable rke2-server.service

    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
    echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml" >> ~/.bashrc
    # Making the kubeconfig world-readable, as this is for tests purposes only.
    chmod +r /etc/rancher/rke2/rke2.yaml

    kubectl wait "$(kubectl get node -o name | head -n1)" --for=condition=ready --timeout=60s
    kubectl wait --timeout=60s --for=condition=ready -n kube-system pod -l app.kubernetes.io/instance=rke2-coredns
    kubectl wait --timeout=60s --for=condition=ready -n kube-system pod -l app.kubernetes.io/component=controller
}

function installRancher(){
    echo "> Installing Cert Manager"
    helm repo add jetstack https://charts.jetstack.io
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager --create-namespace \
        --set crds.enabled=true

    echo "> Installing Rancher Manager"
    kubectl create namespace cattle-system
    helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
    helm install rancher rancher-latest/rancher \
        --namespace cattle-system \
        --set hostname=rancher.local \
        --set replicas=1
    
    # Background processes, such as Fleet deployment need to take place, which
    # may result in intermittent errors. Add some additional waiting time to
    # accommodate such processes.
    sleep 180

    kubectl wait --for=condition=ready -n cattle-system pod -l app=rancher --timeout=120s
    kubectl wait --for=condition=ready -n cattle-system pod -l app=rancher-webhook --timeout=120s
}

function installRancherMonitoring(){
    helm repo add rancher-charts https://charts.rancher.io/

    helm upgrade --install=true \
        --labels=catalog.cattle.io/cluster-repo-name=rancher-charts \
        --namespace=cattle-monitoring-system --timeout=10m0s --wait=true \
        --create-namespace \
        rancher-monitoring-crd rancher-charts/rancher-monitoring-crd

    helm upgrade --install=true \
        --labels=catalog.cattle.io/cluster-repo-name=rancher-charts \
        --namespace=cattle-monitoring-system --timeout=10m0s --wait=true \
        --create-namespace \
        rancher-monitoring rancher-charts/rancher-monitoring

    # Ensure exporter is working before SELinux policy is applied
    kubectl wait --for=condition=ready -n cattle-monitoring-system pod -l app.kubernetes.io/name=prometheus-node-exporter --timeout=60s

    # TODO: Move this to a helm chart value
    kubectl patch daemonset rancher-monitoring-prometheus-node-exporter  -n cattle-monitoring-system -p '{"spec": {"template": {"spec": 
    { "securityContext": {"seLinuxOptions": {"type": "prom_node_exporter_t"}}}}}}'

    # Ensure exporter comes back after SELinux policy is applied
    kubectl wait --for=condition=ready -n cattle-monitoring-system pod -l app.kubernetes.io/name=prometheus-node-exporter --timeout=60s
}

function installRancherLogging(){
    helm repo add rancher-charts https://charts.rancher.io/

    helm upgrade --install=true \
        --labels=catalog.cattle.io/cluster-repo-name=rancher-charts \
        --namespace=cattle-logging-system --timeout=10m0s --wait=true \
        --create-namespace \
        rancher-logging-crd rancher-charts/rancher-logging-crd

    # Install the chart with selinux enabled to true
    helm upgrade --install=true \
        --labels=catalog.cattle.io/cluster-repo-name=rancher-charts \
        --namespace=cattle-logging-system --timeout=10m0s --wait=true \
        --create-namespace \
        rancher-logging rancher-charts/rancher-logging \
        --set global.seLinux.enabled=true

    # Ensure fluentbit daemonset is created
    kubectl wait --for=create -n cattle-logging-system daemonset/rancher-logging-root-fluentbit --timeout=60s
    # Wait for fluentbit pod to be ready
    kubectl wait --for=condition=ready -n cattle-logging-system pod -l app.kubernetes.io/name=fluentbit --timeout=60s
}

function e2eRancherMonitoring(){
    CHART_CONTAINER_EXPECTED_SLTYPE="prom_node_exporter_t"
    CHART_CONTAINER_RUNNING_SLTYPE=""
    CHART_CONTAINER="node-exporter"
    CHART_POD_NAMESPACE="cattle-monitoring-system"
    CHART_POD=$(kubectl get pods -n ${CHART_POD_NAMESPACE} -o custom-columns=NAME:.metadata.name | grep ${CHART_CONTAINER})

    echo "> Verify the presence of ${CHART_CONTAINER_EXPECTED_SLTYPE}"
    if [[ "$(seinfo -t ${CHART_CONTAINER_EXPECTED_SLTYPE} | grep -o ${CHART_CONTAINER_EXPECTED_SLTYPE})" == "${CHART_CONTAINER_EXPECTED_SLTYPE}" ]]; then
        echo "SELinux type is present: ${CHART_CONTAINER_EXPECTED_SLTYPE}"
    else
        echo "SELinux type is not present: ${CHART_CONTAINER_EXPECTED_SLTYPE}"
        exit 1
    fi

    echo "> Verify expected SELinux context type ${CHART_CONTAINER_EXPECTED_SLTYPE} for container ${CHART_CONTAINER}"
    CHART_CONTAINER_RUNNING_SLTYPE=$(kubectl get pod ${CHART_POD} -n ${CHART_POD_NAMESPACE} -o json | jq -r '.spec.securityContext.seLinuxOptions.type')
    if [[ "${CHART_CONTAINER_RUNNING_SLTYPE}" == "${CHART_CONTAINER_EXPECTED_SLTYPE}" ]]; then
        echo "SELinux type is correct: ${CHART_CONTAINER_RUNNING_SLTYPE}"
    else
        echo "SELinux type is incorrect or not set: ${CHART_CONTAINER_RUNNING_SLTYPE}"
        exit 1
    fi

    echo ">Look for any AVCs related to ${CHART_CONTAINER_RUNNING_SLTYPE}"
    if ausearch -m AVC,USER_AVC | grep ${CHART_CONTAINER_RUNNING_SLTYPE} > /dev/null; then
        echo "AVCs found for ${CHART_CONTAINER_RUNNING_SLTYPE}"
        ausearch -m AVC,USER_AVC | grep ${CHART_CONTAINER_RUNNING_SLTYPE}
        exit 1
    else
        echo "No AVCs found for ${CHART_CONTAINER_RUNNING_SLTYPE}"
    fi
}

function e2eRancherLogging(){
    CHART_CONTAINER_EXPECTED_SLTYPE="rke_logreader_t"
    CHART_CONTAINER_RUNNING_SLTYPE=""
    CHART_CONTAINER="fluentbit"
    CHART_POD_NAMESPACE="cattle-logging-system"
    CHART_POD=$(kubectl get pods -n ${CHART_POD_NAMESPACE} -o custom-columns=NAME:.metadata.name | grep "${CHART_CONTAINER}")

    echo "> Verify the presence of ${CHART_CONTAINER_EXPECTED_SLTYPE}"
    if [[ "$(seinfo -t ${CHART_CONTAINER_EXPECTED_SLTYPE} | grep -o ${CHART_CONTAINER_EXPECTED_SLTYPE})" == "${CHART_CONTAINER_EXPECTED_SLTYPE}" ]]; then
        echo "SELinux type is present: ${CHART_CONTAINER_EXPECTED_SLTYPE}"
    else
        echo "SELinux type is not present: ${CHART_CONTAINER_EXPECTED_SLTYPE}"
    fi

    echo "> Verify expected SELinux context type ${CHART_CONTAINER_EXPECTED_SLTYPE} for container ${CHART_CONTAINER}"
    CHART_CONTAINER_RUNNING_SLTYPE=$(kubectl get pod ${CHART_POD} -n ${CHART_POD_NAMESPACE} -o json | jq -r '.spec.containers[0].securityContext.seLinuxOptions.type')
    if [[ "${CHART_CONTAINER_RUNNING_SLTYPE}" == "${CHART_CONTAINER_EXPECTED_SLTYPE}" ]]; then
        echo "SELinux type is correct: ${CHART_CONTAINER_RUNNING_SLTYPE}"
    else
        echo "SELinux type is incorrect or not set: ${CHART_CONTAINER_RUNNING_SLTYPE}"
        exit 1
    fi

    echo ">Look for any AVCs related to ${CHART_CONTAINER_RUNNING_SLTYPE}"
    if ausearch -m AVC,USER_AVC | grep ${CHART_CONTAINER_RUNNING_SLTYPE} > /dev/null; then
        echo "AVCs found for ${CHART_CONTAINER_RUNNING_SLTYPE}"
        ausearch -m AVC,USER_AVC | grep ${CHART_CONTAINER_RUNNING_SLTYPE}
        exit 1
    else
        echo "No AVCs found for ${CHART_CONTAINER_RUNNING_SLTYPE}"
    fi
}

function main(){
    enforceSELinux
    installDependencies
    installRKE2
    installRancher
    installRancherMonitoring
    installRancherLogging
    e2eRancherMonitoring
    e2eRancherLogging
}

# This is needed as Rocky does not include it in the PATH,
# which is required for the Helm install.
export PATH=$PATH:/usr/local/bin

main

