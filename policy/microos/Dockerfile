FROM opensuse/tumbleweed

RUN zypper install -y \
        container-selinux \
        selinux-policy-devel \
        rpm-build

WORKDIR /src

ARG POLICY
COPY policy/${POLICY}/rancher-selinux.spec \
     policy/${POLICY}/rancher.fc \
     policy/${POLICY}/rancher.te \
     hack/build .
