ARG POLICY

# This Dockerfile is used to create the appropriate environment
# to build the SELinux policies and package them as RPM for each
# of the target platforms.

FROM quay.io/centos/centos:centos7 as centos7

# CentOS7 is now EOL and the DNS it relied on for mirror lists
# (mirrorlist.centos.org), no longer resolves.
# The adhoc solution is to disable the use of the mirrorlist and default
# to vault.centos.org instead.
#
# https://blog.centos.org/2023/04/end-dates-are-coming-for-centos-stream-8-and-centos-linux-7/
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* && \
        sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

RUN yum install -y \
        createrepo_c \
        epel-release \
        container-selinux \
        selinux-policy-devel \
        yum-utils \
        rpm-build \
        rpm-sign expect

# Confirm this is needed, move to final if not.
COPY hack/centos7_sign /usr/local/bin/sign

FROM quay.io/centos/centos:stream8 as centos8

# Stream8 is now EOL and the DNS it relied on for mirror lists
# (mirrorlist.centos.org), no longer resolves.
# The adhoc solution is to disable the use of the mirrorlist and default
# to vault.centos.org instead.
#
# https://blog.centos.org/2023/04/end-dates-are-coming-for-centos-stream-8-and-centos-linux-7/
RUN sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-* && \
        sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*

RUN yum install -y \
        createrepo_c \
        epel-release \
        container-selinux \
        selinux-policy-devel \
        yum-utils \
        rpm-build \
        rpm-sign

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
        rpm-sign

# Move to final stage if centos7_sign is removed.
COPY hack/sign /usr/local/bin/sign

FROM fedora:37 as fedora37
RUN dnf install -y \
        createrepo_c \
        container-selinux \
        selinux-policy-devel \
        rpm-build \
        rpm-sign

# Move to final stage if centos7_sign is removed.
COPY hack/sign /usr/local/bin/sign

FROM opensuse/tumbleweed as microos
RUN zypper install -y \
        container-selinux \
        selinux-policy-devel \
        rpm-build \
        rpm

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
     hack/metadata .
