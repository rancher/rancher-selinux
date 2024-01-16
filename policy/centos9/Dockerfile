FROM quay.io/centos/centos:stream9

RUN yum install -y \
        epel-release \
        container-selinux \
        selinux-policy-devel \
        yum-utils \
        rpm-build

WORKDIR /src

ARG POLICY
COPY policy/${POLICY}/rancher-selinux.spec \
     policy/${POLICY}/rancher.fc \
     policy/${POLICY}/rancher.te \
     hack/build .
