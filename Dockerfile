ARG POLICY

# This Dockerfile is used to create the appropriate environment
# to build the SELinux policies and package them as RPM for each
# of the target platforms.

FROM quay.io/centos/centos:centos7 as centos7
RUN yum install -y \
        createrepo_c \
        epel-release \
        container-selinux \
        selinux-policy-devel \
        yum-utils \
        rpm-build \
        rpm-sign expect \
        unzip

# Confirm this is needed, move to final if not.
COPY hack/centos7_sign /usr/local/bin/sign

FROM quay.io/centos/centos:stream8 as centos8
RUN yum install -y \
        createrepo_c \
        epel-release \
        container-selinux \
        selinux-policy-devel \
        yum-utils \
        rpm-build \
        rpm-sign \
        unzip

# Move to final stage if centos7_sign is removed.
COPY hack/sign /usr/local/bin/sign

FROM quay.io/centos/centos:stream9 as centos9
RUN yum install -y \
        createrepo_c \
        epel-release \
        container-selinux \
        selinux-policy-devel \
        yum-utils \
        rpm-build \
        rpm-sign \
        unzip

# Move to final stage if centos7_sign is removed.
COPY hack/sign /usr/local/bin/sign

FROM fedora:37 as fedora37
RUN dnf install -y \
        createrepo_c \
        container-selinux \
        selinux-policy-devel \
        rpm-build \
        rpm-sign \
        unzip

# Move to final stage if centos7_sign is removed.
COPY hack/sign /usr/local/bin/sign

FROM opensuse/tumbleweed as microos
RUN zypper install -y \
        container-selinux \
        selinux-policy-devel \
        rpm-build \
        rpm \
        unzip

# libglib is required to install createrepo_c in Tumbleweed.
RUN zypper install -y libglib-2_0-0 createrepo_c

# Move to final stage if centos7_sign is removed.
COPY hack/sign /usr/local/bin/sign

# Pick base image based on the target policy.
FROM ${POLICY} as final

WORKDIR /src

ARG POLICY
COPY policy/${POLICY}/rancher-selinux.spec \
     policy/${POLICY}/rancher.fc \
     policy/${POLICY}/rancher.te \
     hack/build \
     hack/repo-metadata .
