# vim: sw=4:ts=4:et

# A single spec is used for every supported distribution. The target
# distribution is selected at build time with --define "distro <name>",
# where <name> matches a build stage in the Dockerfile.

%if "%{distro}" == "centos9"
%global dist_suffix el9
%global selinux_policyver 2.240.0-3
%global container_policyver 2.232.1-1
%endif

%if "%{distro}" == "centos10"
%global dist_suffix el10
%global selinux_policyver 42.1.7-1
%global container_policyver 2.240.0-1
%endif

%if "%{distro}" == "fedora43"
%global dist_suffix fc43
%global selinux_policyver 43.10-1
%global container_policyver 2.250.0-1
%endif

%if "%{distro}" == "microos"
%global dist_suffix microos
%global selinux_policyver 20260219-1.1
%global container_policyver 2.246.0-1.1
%global suse 1
%endif

%if "%{distro}" == "sle"
%global dist_suffix sle
%global selinux_policyver 20250627+git398.8dcc9d038-160000.1.1
%global container_policyver 2.239.0-160000.3.1
%global suse 1
%endif

%{!?dist_suffix:%{error:unsupported distro "%{?distro}", set --define "distro <name>"}}

Name:   rancher-selinux
Version:	%{rancher_selinux_version}
Release:	%{rancher_selinux_release}.%{dist_suffix}
Summary:	SELinux policy module for Rancher
Vendor:     SUSE LLC
Packager:   SUSE LLC <https://www.suse.com/>

Group:	System Environment/Base
License:	Apache-2.0
URL:		http://rancher.com
Source0:	rancher.pp

BuildRequires: container-selinux >= %{container_policyver}

%if 0%{?suse}
Requires: policycoreutils, selinux-tools, container-selinux >= %{container_policyver}
%else
Requires: policycoreutils, libselinux-utils, container-selinux >= %{container_policyver}
%endif
Requires(post): selinux-policy >= %{selinux_policyver}, policycoreutils, container-selinux >= %{container_policyver}
Requires(postun): policycoreutils

BuildArch: noarch

%description
This package installs and sets up the SELinux policy security module for Rancher.

%install
install -d %{buildroot}%{_datadir}/selinux/packages
install -m 644 %{SOURCE0} %{buildroot}%{_datadir}/selinux/packages

# On SUSE the module is loaded in %%posttrans so that it is installed after
# container-selinux, whose types it depends on.
%if 0%{?suse}
%posttrans
%else
%post
%endif
semodule -n -i %{_datadir}/selinux/packages/rancher.pp
if /usr/sbin/selinuxenabled ; then
    /usr/sbin/load_policy
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
