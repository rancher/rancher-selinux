ARG POLICY

# This Dockerfile is used to create the appropriate environment
# to build the SELinux policies and package them as RPM for each
# of the target platforms.

FROM quay.io/rockylinux/rockylinux:9@sha256:53f4c6dcb34e1403bd93207351f0af9a593610faeb7165cb8a037346765199b0 AS centos9
RUN yum install -y \
        createrepo_c \
        epel-release \
        container-selinux \
        selinux-policy-devel \
        yum-utils \
        rpm-build \
        rpm-sign

FROM quay.io/rockylinux/rockylinux:10@sha256:f4da504c18e7aced902f4f728cde787cd9d9b817bc639fe171026d18364dca6c AS centos10
RUN yum install -y \
        createrepo_c \
        epel-release \
        container-selinux \
        selinux-policy-devel \
        yum-utils \
        rpm-build \
        rpm-sign \
        gnupg2

FROM fedora:42@sha256:eb167a7adffa1489a205c83a7b9324e4cb0fae5c54645f263e70ac13f661f0e8 AS fedora42
RUN dnf clean all && dnf install -y \
        createrepo_c \
        container-selinux \
        selinux-policy-devel \
        rpm-build \
        rpm-sign

FROM opensuse/tumbleweed@sha256:9ecf351b94f19a4258076ba06173aed6dd5d8a23b08add5b691e8772738d7f7c AS microos
RUN zypper install -y \
        container-selinux \
        selinux-policy-devel \
        rpm-build \
        rpm

# libglib is required to install createrepo_c in Tumbleweed.
RUN zypper install -y libglib-2_0-0 createrepo_c

# Pick base image based on the target policy.
FROM ${POLICY} AS final

WORKDIR /src

ARG POLICY
COPY hack/sign /usr/local/bin/sign
COPY policy/${POLICY}/rancher-selinux.spec \
     policy/${POLICY}/rancher.fc \
     policy/${POLICY}/rancher.te \
     hack/build \
     hack/metadata ./
