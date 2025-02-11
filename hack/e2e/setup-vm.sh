#!/bin/bash

set -xo pipefail

function enforceSELinux(){
    echo "> Check SELinux status"
    # Short circuit if SELinux is not being enforced.
    getenforce | grep -q Enforcing
}

function installDependencies(){
    echo 'echo "export PATH=$PATH:/usr/local/bin"' >> ~/.bashrc
    echo 'echo "export TERM=xterm"' >> ~/.bashrc

    # Git is required by helm
    yum in -y git

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
        --set bootstrapPassword="${ADMIN_PASSWORD}" \
        --set hostname=rancher.local \
        --set replicas=1
    
    kubectl wait --for=condition=ready -n cattle-system pod -l app=rancher --timeout=60s
    kubectl wait --for=condition=ready -n cattle-system pod -l app=rancher-webhook --timeout=60s
}

function E2E(){
    echo "<!-- Execute some RM op here -->"
}

function main(){
    enforceSELinux
    installDependencies
    installRKE2
    installRancher

    E2E
}


# This is needed as Rocky does not include it in the PATH,
# which is required for the Helm install.
export PATH=$PATH:/usr/local/bin

export ADMIN_PASSWORD=$(head -c 16 /dev/urandom | base64 | tr -dc '[:alnum:]')

main
