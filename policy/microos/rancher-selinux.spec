# vim: sw=4:ts=4:et

%define selinux_policyver 20250507-1.1
%define container_policyver 2.237.0-1.1

%define relabel_files() \
mkdir -p /var/lib/rancher/rke /etc/kubernetes /opt/rke; \
restorecon -R /var/lib/rancher /etc/kubernetes /opt/rke;

Name:   rancher-selinux
Version:	%{rancher_selinux_version}
Release:	%{rancher_selinux_release}.sle
Summary:	SELinux policy module for Rancher

Group:	System Environment/Base
License:	Apache-2.0
URL:		http://rancher.com
Source0:	rancher.pp

BuildRequires: container-selinux >= %{container_policyver}

Requires: policycoreutils, selinux-tools
Requires(post): selinux-policy-base >= %{selinux_policyver}, policycoreutils, container-selinux >= %{container_policyver}
Requires(postun): policycoreutils

BuildArch: noarch

%description
This package installs and sets up the SELinux policy security module for Rancher.

%install
install -d %{buildroot}%{_datadir}/selinux/packages
install -m 644 %{SOURCE0} %{buildroot}%{_datadir}/selinux/packages


%post
semodule -n -i %{_datadir}/selinux/packages/rancher.pp
if /usr/sbin/selinuxenabled ; then
    /usr/sbin/load_policy
    %relabel_files
fi;
exit 0

%postun
if [ $1 -eq 0 ]; then
    semodule -n -r rancher
    if /usr/sbin/selinuxenabled ; then
       /usr/sbin/load_policy
    fi;
fi;
exit 0

%files
%attr(0600,root,root) %{_datadir}/selinux/packages/rancher.pp

%changelog
