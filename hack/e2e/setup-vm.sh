#!/bin/bash

set -euxo pipefail

function enforceSELinux(){
    echo "> Check SELinux status"
    # Short circuit if SELinux is not being enforced.
    getenforce | grep -q Enforcing

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

    echo "> Installing kubectl ${KUBECTL_VERSION}"
    curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
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

function E2E(){
    echo "<!-- Execute some RM op here -->"
}

function main(){
    enforceSELinux
    installDependencies
    installRKE2
    installRancher
    installRancherMonitoring

    E2E
}

# This is needed as Rocky does not include it in the PATH,
# which is required for the Helm install.
export PATH=$PATH:/usr/local/bin

main
