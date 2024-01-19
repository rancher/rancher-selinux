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
        rpm-build

FROM quay.io/centos/centos:stream8 as centos8
RUN yum install -y \
        createrepo_c \
        epel-release \
        container-selinux \
        selinux-policy-devel \
        yum-utils \
        rpm-build

FROM quay.io/centos/centos:stream9 as centos9
RUN yum install -y \
        createrepo_c \
        epel-release \
        container-selinux \
        selinux-policy-devel \
        yum-utils \
        rpm-build

FROM fedora:37 as fedora37
RUN dnf install -y \
        createrepo_c \
        container-selinux \
        selinux-policy-devel \
        rpm-build

FROM opensuse/tumbleweed as microos
RUN zypper install -y \
        container-selinux \
        selinux-policy-devel \
        rpm-build

# libglib is required to install createrepo_c in Tumbleweed.
RUN zypper install -y libglib-2_0-0 createrepo_c

# Pick base image based on the target policy.
FROM ${POLICY}

WORKDIR /src

ARG POLICY
COPY policy/${POLICY}/rancher-selinux.spec \
     policy/${POLICY}/rancher.fc \
     policy/${POLICY}/rancher.te \
     hack/build .
