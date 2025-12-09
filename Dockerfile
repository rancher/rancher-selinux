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

FROM quay.io/centos/centos:stream9@sha256:0bf070f10582acaa3c415280f769797025763c8a8e6509a5883592d0872a56d6 AS centos9
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

FROM opensuse/tumbleweed:latest@sha256:e6078e56685808dc36d5b31a13c80e4ecf1ebcae06476d8153d0d8be777f58ce AS microos
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
