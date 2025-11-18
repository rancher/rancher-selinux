ARG POLICY

# This Dockerfile is used to create the appropriate environment
# to build the SELinux policies and package them as RPM for each
# of the target platforms.

FROM quay.io/centos/centos:stream8@sha256:20da069d4f8126c4517ee563e6e723d4cbe79ff62f6c4597f753478af91a09a3 AS centos8


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

FROM quay.io/centos/centos:stream9@sha256:e15ceb6e8744ccb658c6d8cb81cf2853398ca3a611f41f0b8e2fce655361190d AS centos9
RUN yum install -y \
        createrepo_c \
        epel-release \
        container-selinux \
        selinux-policy-devel \
        yum-utils \
        rpm-build \
        rpm-sign

FROM fedora:41@sha256:c3643bda846169b342b400d4bbd1cb7022a7037e108b403a97305d1cb1644bcd AS fedora41
RUN dnf install -y \
        createrepo_c \
        container-selinux \
        selinux-policy-devel \
        rpm-build \
        rpm-sign

FROM opensuse/tumbleweed:latest@sha256:fef63b8f471b4968309bbc9065a176202e30d67df56d3b8b9962a7cb8ea934d9 AS microos
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
