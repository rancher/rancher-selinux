ARG POLICY

# This Dockerfile is used to create the appropriate environment
# to build the SELinux policies and package them as RPM for each
# of the target platforms.

FROM quay.io/rockylinux/rockylinux:9@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f AS centos9
RUN yum install -y \
        createrepo_c \
        epel-release \
        container-selinux \
        selinux-policy-devel \
        yum-utils \
        rpm-build \
        rpm-sign

FROM quay.io/rockylinux/rockylinux:10@sha256:827d37bc128288ccf160ee318bb3cb92d591164cb217e92f8bc61e3982ae1834 AS centos10
RUN yum install -y \
        createrepo_c \
        epel-release \
        container-selinux \
        selinux-policy-devel \
        yum-utils \
        rpm-build \
        rpm-sign \
        gnupg2

FROM fedora:43@sha256:f01112b9a1f1d0504ad962d9adfa401425033f8ab067e0a821904ebdde5b8ca5 AS fedora43
RUN dnf clean all && dnf install -y \
        createrepo_c \
        container-selinux \
        selinux-policy-devel \
        rpm-build \
        rpm-sign

FROM opensuse/tumbleweed@sha256:e420f56a78b0994c40a0288043786dfac2cd317f32ae28eca2940b0d809c531f AS microos
RUN zypper install -y \
        container-selinux \
        findutils \
        selinux-policy-devel \
        rpm-build \
        rpm
# libglib is required to install createrepo_c in Tumbleweed.
RUN zypper install -y libglib-2_0-0 createrepo_c

FROM opensuse/leap:16.0@sha256:a4115e2f5aea9712a7c73974fd94000a034fc3051ef29b5f7722fbf04070dd9d AS sle
RUN zypper install -y \
        container-selinux \
        findutils \
        selinux-policy-devel \
        rpm-build \
        rpm

# libglib is required to install createrepo_c in Leap.
RUN zypper install -y libglib-2_0-0 createrepo_c

# Pick base image based on the target policy.
FROM ${POLICY} AS final

WORKDIR /src

ARG POLICY
ENV POLICY=${POLICY}
COPY hack/sign /usr/local/bin/sign
COPY policy/rancher-selinux.spec \
     policy/rancher.fc \
     policy/rancher.te \
     hack/build \
     hack/metadata ./
