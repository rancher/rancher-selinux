# rancher-selinux
Rancher selinux policy repository

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
