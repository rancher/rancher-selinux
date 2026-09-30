# rancher-selinux

[![OpenSSF Scorecard](https://api.scorecard.dev/projects/github.com/rancher/rancher-selinux/badge)](https://scorecard.dev/viewer/?uri=github.com/rancher/rancher-selinux)

`rancher-selinux` contains a set of SELinux policies designed to grant the necessary privileges to various Rancher components running on Linux systems with SELinux enabled. These policies enhance security by defining dedicated types for containers and assigning them the least privileges possible.

For the full guide on using SELinux with Rancher, see the [Rancher documentation][docs].

## Installation

Pick the repository path for your OS from the [support matrix](#support-matrix).

**RHEL / CentOS / Rocky / Fedora**

```bash
cat << EOF > /etc/yum.repos.d/rancher.repo
[rancher]
name=Rancher
baseurl=https://rpm.rancher.io/rancher/production/<repo-path>/noarch
enabled=1
gpgcheck=1
gpgkey=https://rpm.rancher.io/public.key
EOF

dnf install -y rancher-selinux
```

**openSUSE / SLE / SLE Micro**

```bash
cat << EOF > /etc/zypp/repos.d/rancher.repo
[rancher]
name=Rancher
baseurl=https://rpm.rancher.io/rancher/production/<repo-path>/noarch
enabled=1
gpgcheck=1
gpgkey=https://rpm.rancher.io/public.key
EOF

zypper --gpg-auto-import-keys refresh
zypper install -y rancher-selinux
```

On transactional systems (SLE Micro, MicroOS), use `transactional-update pkg install rancher-selinux` and reboot.

Verify the modules are loaded:

```bash
semodule -l | grep rancher
```

Installing the RPM is not enough on its own: charts must be configured to run in the provided SELinux types. Set `global.seLinux.enabled=true` when installing a supported chart.

## Support Matrix

| Operating System                | Version | Repo path   | RPM extension | Policy     |
| :------------------------------ | :------ | :---------- | :------------ | :--------- |
| openSUSE Leap / SLE / SLE Micro | 16 / 6  | `sle/16`    | `.sle`        | [sle]      |
| openSUSE MicroOS / Tumbleweed   | Rolling | `microos`   | `.microos`    | [microos]  |
| RHEL / CentOS / Rocky           | 9       | `centos/9`  | `.el9`        | [centos9]  |
| RHEL / CentOS / Rocky           | 10      | `centos/10` | `.el10`       | [centos10] |
| Fedora                          | 43      | `fedora/43` | `.fc43`       | [fedora43] |

All policies are covered by end-to-end tests in CI.

## Coverage

| Component          | Container                            | SELinux type                  | Status     |
| :----------------- | :----------------------------------- | :---------------------------- | :--------- |
| Rancher Monitoring | [node-exporter]                      | `prom_node_exporter_t`        | Production |
| Rancher Monitoring | [pushprox]                           | `rke_kubereader_t`            | Production |
| Rancher Logging    | [fluentbit]                          | `rke_logreader_t`             | Production |
| Rancher AI         | [rancher-ai-agent]                   | `rancher_aiagent_container_t` | Production |
| Rancher AI         | [rancher-ai-mcp]                     | `rancher_aimcp_container_t`   | Production |
| RKE1               | [flannel]                            | `rke_network_t`               | EOL        |
| RKE1               | [rke] `etcd`, `kube-apiserver`, etc. | `rke_container_t`             | EOL        |

> **Note:** Only the components listed above get a dedicated SELinux type. Other Rancher components and workloads use the default `container_t` type from `container-selinux`.

## Development

Requires Docker (or set `RUNNER=podman`). End-to-end tests require [Lima](https://lima-vm.io).

| Command               | Description                                        |
| :-------------------- | :------------------------------------------------- |
| `make build`          | Build all policies                                 |
| `make <policy>-build` | Build a single policy (e.g. `make sle-build`)      |
| `make e2e-<distro>`   | Run end-to-end tests in a VM (e.g. `make e2e-sle`) |

Artefacts are written to `build/<policy>/`.

### Adding a new distribution

1. Add `policy/<name>/` with `rancher-selinux.spec`, `rancher.te` and `rancher.fc`.
2. Add a matching `<name>` build stage to the `Dockerfile`.
3. Add `hack/e2e/<name>.yaml` (Lima template) and the distro to `.github/workflows/e2e.yml`.
4. Map the policy to its repo path in `hack/upload`.
5. Update the support matrix above.

## Releasing

Tags follow the format `v{version}.{channel}.{release}`, which maps directly to RPM naming:

- `version`: rancher-selinux version, e.g. `0.1`, `0.2`
- `channel`: `testing` or `production`
- `release`: RPM release, starting at `1`

Testing RPMs are published to `https://rpm-testing.rancher.io/rancher/testing/<repo-path>/noarch`.

| Tag                     | Output RPM                                      | Channel    |
| :---------------------- | :---------------------------------------------- | :--------- |
| `main` (no tag)         | `rancher-selinux-0.0~0d52f7d8-0.el9.noarch.rpm` | Testing    |
| `v0.2-alpha1.testing.1` | `rancher-selinux-0.2~alpha1-1.el9.noarch.rpm`   | Testing    |
| `v0.2-rc1.testing.1`    | `rancher-selinux-0.2~rc1-1.el9.noarch.rpm`      | Testing    |
| `v0.2.testing.1`        | `rancher-selinux-0.2-1.el9.noarch.rpm`          | Testing    |
| `v0.2.production.1`     | `rancher-selinux-0.2-1.el9.noarch.rpm`          | Production |

[docs]: https://ranchermanager.docs.rancher.com/reference-guides/rancher-security/selinux-rpm/about-rancher-selinux
[centos9]: https://github.com/rancher/rancher-selinux/tree/main/policy/centos9
[centos10]: https://github.com/rancher/rancher-selinux/tree/main/policy/centos10
[fedora43]: https://github.com/rancher/rancher-selinux/tree/main/policy/fedora43
[microos]: https://github.com/rancher/rancher-selinux/tree/main/policy/microos
[sle]: https://github.com/rancher/rancher-selinux/tree/main/policy/sle
[fluentbit]: https://github.com/rancher/charts/blob/262597a41a175cfb4785d70fd76b33d56f8c1f95/charts/rancher-logging/106.0.1%2Bup4.10.0-rancher.4/templates/loggings/k3s/daemonset.yaml#L22
[node-exporter]: https://github.com/rancher/charts/blob/262597a41a175cfb4785d70fd76b33d56f8c1f95/charts/rancher-monitoring/106.0.1%2Bup66.7.1-rancher.10/charts/prometheus-node-exporter/templates/daemonset.yaml#L51
[flannel]: https://github.com/rancher/kontainer-driver-metadata/blob/34e1e8a7a157daae54b310b199aa663c9a2ef314/rke/templates/flannel_v0.14.0.go#L239
[pushprox]: https://github.com/rancher/charts/tree/dev-v2.11/charts/rancher-monitoring/106.0.1%2Bup66.7.1-rancher.10/charts/rkeEtcd
[rke]: https://github.com/rancher/rke/blob/5756a3837a3c49d61f1ea2120b02149c21e4a443/hosts/hosts.go#L55
[rancher-ai-agent]: https://github.com/rancher/rancher-ai-agent
[rancher-ai-mcp]: https://github.com/rancher/rancher-ai-mcp
