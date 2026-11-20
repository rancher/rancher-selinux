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

| Operating System                | Version | Build target | Repo path   | RPM extension |
| :------------------------------ | :------ | :----------- | :---------- | :------------ |
| openSUSE Leap / SLE / SLE Micro | 16 / 6  | `sle`        | `sle/16`    | `.sle`        |
| openSUSE MicroOS / Tumbleweed   | Rolling | `microos`    | `microos`   | `.microos`    |
| RHEL / CentOS / Rocky           | 9       | `centos9`    | `centos/9`  | `.el9`        |
| RHEL / CentOS / Rocky           | 10      | `centos10`   | `centos/10` | `.el10`       |
| Fedora                          | 43      | `fedora43`   | `fedora/43` | `.fc43`       |

All distributions are built from a single [policy] (`policy/rancher.te`). Per-distribution packaging details (RPM extension, minimum `selinux-policy` and `container-selinux` versions, SUSE-specific dependencies) live in `policy/rancher-selinux.spec`.

All distributions are covered by end-to-end tests in CI.

## Coverage

| Component          | Container                            | SELinux type                  | Status     |
| :----------------- | :----------------------------------- | :---------------------------- | :--------- |
| Rancher Monitoring | [node-exporter]                      | `prom_node_exporter_t`        | Production |
| Rancher Monitoring | [pushprox]                           | `rke_kubereader_t`            | Production |
| Rancher Logging    | [fluentbit]                          | `rke_logreader_t`             | Production |
| Rancher AI         | [rancher-ai-agent]                   | `rancher_aiagent_container_t` | Production |
| Rancher AI         | [rancher-ai-mcp]                     | `rancher_aimcp_container_t`   | Production |

> **Note:** Only the components listed above get a dedicated SELinux type. Other Rancher components and workloads use the default `container_t` type from `container-selinux`.

## Development

Requires Docker (or set `RUNNER=podman`). End-to-end tests require [Lima](https://lima-vm.io).

| Command               | Description                                                |
| :-------------------- | :--------------------------------------------------------- |
| `make build`          | Build the RPM for all distributions                        |
| `make <distro>-build` | Build the RPM for one distribution (e.g. `make sle-build`) |
| `make e2e-<distro>`   | Run end-to-end tests in a VM (e.g. `make e2e-sle`)         |

Artefacts are written to `build/<distro>/`.

### Adding a new distribution

1. Add a `%if "%{distro}" == "<name>"` block to `policy/rancher-selinux.spec` with its RPM extension and minimum package versions.
2. Add a matching `<name>` build stage to the `Dockerfile` and add `<name>` to `POLICIES` in the `Makefile`.
3. Add `hack/e2e/<name>.yaml` (Lima template) and the distro to `.github/workflows/e2e.yml`.
4. Map the policy to its repo path in `hack/upload`.
5. Update the support matrix above.

## Versioning

rancher-selinux follows [Semantic Versioning](https://semver.org) (`MAJOR.MINOR.PATCH`), applied to what users of the policy depend on:

- the SELinux types that charts set in `seLinuxOptions.type`;
- the permissions released chart versions need to function;
- file contexts in `rancher.fc` and booleans, if any;
- the supported distributions and their minimum `selinux-policy` / `container-selinux` versions.

| Bump | When |
| :--- | :--- |
| **MAJOR** | A change that can break a chart version or host that worked before: removing or renaming a type without keeping a `typealias`, removing permissions a released chart relies on, changing or removing file contexts of existing paths, flipping a boolean default to reduce access, dropping a distribution that is still supported upstream, or raising a minimum dependency above what a supported distribution release ships. |
| **MINOR** | A backwards-compatible addition: a new type, a new distribution, a new boolean that defaults to existing behaviour, file contexts for new paths, deprecating a type via `typealias`, or dropping an end-of-life distribution. |
| **PATCH** | A fix to existing behaviour: adding permissions to an existing type to fix AVC denials, or a spec/packaging fix that changes what gets installed. |
| **Release** | The same version rebuilt, e.g. re-signed or built from refreshed base images. |

Changes that only touch CI, e2e tests or documentation do not need a release.

Removing permissions believed to be unused is a PATCH only if e2e tests show that no supported chart needs them; when in doubt, treat it as MAJOR.

### New types

- New types are released in a MINOR version. A chart must only reference a new type once a rancher-selinux release containing it is in production, and should document that minimum version (e.g. `rancher-selinux >= 1.1.0`), because pods fail to start if their type is not loaded.
- While a type has only been published in pre-releases (`-alphaN`, `-betaN`, `-rcN`), it may still be renamed, tightened or redesigned. Once in a production release, the rules above apply.
- Denials found after a type is released are fixed in PATCH versions.
- New types are named `rancher_<component>_container_t` and come with e2e coverage in `hack/e2e/setup-vm.sh`.

The version in `policy_module(rancher, ...)` is not used: SELinux drops it when the module is installed. The RPM version (`rpm -q rancher-selinux`) is the source of truth.

## Releasing

Releases are cut by pushing a tag:

- `v{MAJOR}.{MINOR}.{PATCH}-{alpha,beta,rc}{N}.testing.{release}` publishes a pre-release to the testing channel.
- `v{MAJOR}.{MINOR}.{PATCH}.production.{release}` publishes a final release to the production channel.

`release` is the RPM release, starting at `1`. Pre-releases cannot be published to production and final versions cannot be published to testing, so the same RPM version-release is never built twice. Pre-release suffixes become `~` in the RPM version, which RPM sorts before the final version (`1.0.0~rc1` < `1.0.0`).

Testing RPMs are published to `https://rpm-testing.rancher.io/rancher/testing/<repo-path>/noarch`.

| Tag                       | Output RPM                                       | Channel    |
| :------------------------ | :----------------------------------------------- | :--------- |
| `main` (no tag)           | `rancher-selinux-0.0.0~f20a4e3-0.el9.noarch.rpm` | Testing    |
| `v1.1.0-alpha1.testing.1` | `rancher-selinux-1.1.0~alpha1-1.el9.noarch.rpm`  | Testing    |
| `v1.1.0-rc1.testing.1`    | `rancher-selinux-1.1.0~rc1-1.el9.noarch.rpm`     | Testing    |
| `v1.1.0-rc1.testing.2`    | `rancher-selinux-1.1.0~rc1-2.el9.noarch.rpm`     | Testing    |
| `v1.1.0.production.1`     | `rancher-selinux-1.1.0-1.el9.noarch.rpm`         | Production |
| `v1.1.1.production.1`     | `rancher-selinux-1.1.1-1.el9.noarch.rpm`         | Production |

[docs]: https://ranchermanager.docs.rancher.com/reference-guides/rancher-security/selinux-rpm/about-rancher-selinux
[policy]: https://github.com/rancher/rancher-selinux/tree/main/policy
[fluentbit]: https://github.com/rancher/charts/blob/262597a41a175cfb4785d70fd76b33d56f8c1f95/charts/rancher-logging/106.0.1%2Bup4.10.0-rancher.4/templates/loggings/k3s/daemonset.yaml#L22
[node-exporter]: https://github.com/rancher/charts/blob/262597a41a175cfb4785d70fd76b33d56f8c1f95/charts/rancher-monitoring/106.0.1%2Bup66.7.1-rancher.10/charts/prometheus-node-exporter/templates/daemonset.yaml#L51
[pushprox]: https://github.com/rancher/charts/tree/dev-v2.11/charts/rancher-monitoring/106.0.1%2Bup66.7.1-rancher.10/charts/rkeEtcd
[rancher-ai-agent]: https://github.com/rancher/rancher-ai-agent
[rancher-ai-mcp]: https://github.com/rancher/rancher-ai-mcp
