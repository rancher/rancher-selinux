# About rancher-selinux [![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/rancher/rancher-selinux/badge)](https://scorecard.dev/viewer/?uri=github.com/rancher/rancher-selinux)

`rancher-selinux` contains a set of SELinux policies designed to grant the necessary privileges to various Rancher components running on Linux systems with SELinux enabled. These policies enhance security by defining dedicated types for containers and assigning them the least privileges possible.

For more information about enabling SELinux on Rancher or installing the rancher-selinux RPM, use: https://ranchermanager.docs.rancher.com/reference-guides/rancher-security/selinux-rpm/about-rancher-selinux

## Coverage of rancher-selinux

The following Rancher compnents are covered by the policy:

| Component                  | Service/Container                                                        | SELinux Type           |
| :------------------------- | :----------------------------------------------------------------------- | :--------------------- |
| Rancher Monitoring Chart   | [node-exporter]                                                          | `prom_node_exporter_t` |
| Rancher Monitoring Chart   | [pushprox]                                                               | `rke_kubereader_t`     |
| Rancher Logging Chart      | [fluentbit]                                                              | `rke_logreader_t`      |
| RKE1                       | [flannel]                                                                | `rke_network_t`        |
| RKE1                       | [rke] `etcd`, `rke-etcd-backup`, `kube-{apiserver,controller,scheduler}` | `rke_container_t`      |

## Support Matrix

| Operating System      | Version | Supported          | Policy     | E2E                   |
| :-------------------- | :------ | :----------------- | :--------- | :-------------------- |
| RHEL/CentOS/Rocky     | 8       | :white_check_mark: | [centos8]  | :white_check_mark:    |
| RHEL/CentOS/Rocky     | 9       | :white_check_mark: | [centos9]  | :white_check_mark:    |
| RHEL/CentOS/Rocky     | 10      | :white_check_mark: | [centos10] | :white_check_mark:    |
| Fedora                | 42      | :white_check_mark: | [fedora42] | :white_check_mark:    |
| SUSE SLE/Micro        | Stable  | :white_check_mark: | [microos]  | :construction:        |

## Versioning/Tagging

The version parsing logic for `rancher/rancher-selinux` expects tags to be of a certain format (that directly correlates to RPM naming)

The tag format should be as follows: `v{rancher-selinux version}.{rpm channel}.{rpm release}` where

rancher-selinux-version is like `0.1`, `0.2`, etc.
rpm channel is like `testing`, `production`
rpm release is like `1`, `2`

rpm release should index from `1` for released RPM's

The following list shows the expected tag to (example) transformation for RPM's

|Tag|Tree State|Output RPM|RPM Channel|Notes|
|:--|:---------|:---------|:----------|:----|
| master (no tag) | Clean | `rancher-selinux-0.0~0d52f7d8-0.el7.noarch.rpm` | Testing ||
| master (no tag) | Dirty | `rancher-selinux-0.0~0d52f7d8-0.el7.noarch.rpm` | Testing ||
| v0.2-alpha1.testing.1 | Clean | `rancher-selinux-0.2~alpha1-1.el7.noarch.rpm` | Testing ||
| v0.2-alpha2.testing.1 | Clean | `rancher-selinux-0.2~alpha2-1.el7.noarch.rpm` | Testing ||
| v0.2-rc1.testing.1 | Clean | `rancher-selinux-0.2~rc1-1.el7.noarch.rpm` | Testing ||
| v0.2-rc2.testing.1 | Clean | `rancher-selinux-0.2~rc2-1.el7.noarch.rpm` | Testing ||
| v0.2.testing.1 | Clean | `rancher-selinux-0.2-1.el7.noarch.rpm` | Testing ||
| v0.2.production.1 | Clean | `rancher-selinux-0.2-1.el7.noarch.rpm` | Production ||

[centos8]: https://github.com/rancher/rancher-selinux/tree/main/policy/centos8
[centos9]: https://github.com/rancher/rancher-selinux/tree/main/policy/centos9
[centos10]: https://github.com/rancher/rancher-selinux/tree/main/policy/centos10
[fedora42]: https://github.com/rancher/rancher-selinux/tree/main/policy/fedora42
[microos]: https://github.com/rancher/rancher-selinux/tree/main/policy/microos
[fluentbit]: https://github.com/rancher/charts/blob/262597a41a175cfb4785d70fd76b33d56f8c1f95/charts/rancher-logging/106.0.1%2Bup4.10.0-rancher.4/templates/loggings/k3s/daemonset.yaml#L22
[node-exporter]: https://github.com/rancher/charts/blob/262597a41a175cfb4785d70fd76b33d56f8c1f95/charts/rancher-monitoring/106.0.1%2Bup66.7.1-rancher.10/charts/prometheus-node-exporter/templates/daemonset.yaml#L51
[flannel]: https://github.com/rancher/kontainer-driver-metadata/blob/34e1e8a7a157daae54b310b199aa663c9a2ef314/rke/templates/flannel_v0.14.0.go#L239
[pushprox]: https://github.com/rancher/charts/tree/dev-v2.11/charts/rancher-monitoring/106.0.1%2Bup66.7.1-rancher.10/charts/rkeEtcd
[rke]: https://github.com/rancher/rke/blob/5756a3837a3c49d61f1ea2120b02149c21e4a443/hosts/hosts.go#L55
