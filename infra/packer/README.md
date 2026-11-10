---
title: Oracle workshop image
description: Build the fixed Ubuntu 24.04 Oracle toolchain with local Azure CLI authentication
ms.date: 2026-11-08
---

## Image configuration

The image publishes to subscription `aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483`
in tenant `8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5`:

* Resource group `rg-workshop-images`
* Gallery `gal_oracle_workshop`
* Image definition `oracle-workshop-vm`
* Fresh version `1.1.0`
* Region `francecentral`, one Standard LRS replica
* Temporary build resource group `rg-packer-build`

The parent deployment creates the gallery and image definition. The definition
must be Linux, x64, Hyper-V generation V2, and generalized. Read-only Azure
metadata verified `Canonical:ubuntu-24_04-lts:server:24.04.202610250` as x64/V2.
This exact source version is pinned in the template.

Configure NVMe metadata when creating the definition. Azure rejected extending
the original empty definition in place with a missing
`galleryImageVersionName` error. Its approved recreation preserved the gallery
and added the feature successfully. Never delete published image versions to
enable this change; use a reviewed migration or a new definition instead.

The temporary builder uses `Standard_D4as_v7` with `disk_controller_type=NVMe`.
Participants use `Standard_D2as_v7` in zone 2. The released Packer Azure builder
does not expose an availability-zone setting; its build is regional, with
the regionally permitted SKU. Actual allocation must still succeed.

Packer creates its temporary VM, network, public IP, and disks in the separate
build resource group. It does not depend on the workshop hub or spokes.
`rg-workshop-images` must remain outside hub cleanup.

## Verified toolchain

Official release evidence and local archives were checked on 2026-11-08.
Downloads use fixed URLs and SHA256 checksums in
[`ansible/oracle-tools.yml`](ansible/oracle-tools.yml), never runtime discovery
of a latest release.

* Instant Client Basic and SQL*Plus 23.26.4.0.0:
  [Oracle Linux x64 downloads](https://www.oracle.com/database/technologies/instant-client/linux-x86-64-downloads.html)
* SQLcl 26.3.1.301.1413:
  [Oracle SQLcl downloads](https://www.oracle.com/database/sqldeveloper/technologies/sqlcl/download/)
* rwloadsim, connping, and ociping asset release 3.3.0, binary banner 3.3.0.1:
  [Oracle release v3.3.0](https://github.com/oracle/rwloadsim/releases/tag/v3.3.0)
* Azure CLI 2.92.0, Noble package 2.92.0-1:
  [Microsoft release](https://github.com/Azure/azure-cli/releases/tag/azure-cli-2.92.0)
* Oracle Azure CLI extension 3.0.1:
  [Microsoft extension index](https://azcliextensionsync.blob.core.windows.net/index1/index.json)
* OCI CLI 3.96.0:
  [Oracle release](https://github.com/oracle/oci-cli/releases/tag/v3.96.0)
* Python oracledb 26.1.0:
  [Oracle driver package](https://pypi.org/project/oracledb/26.1.0/)
* BATS 1.14.0:
  [BATS release](https://github.com/bats-core/bats-core/releases/tag/v1.14.0)
* bats-support 0.3.0 and bats-assert 2.2.4:
  [Support](https://github.com/bats-core/bats-support/releases/tag/v0.3.0),
  [assert](https://github.com/bats-core/bats-assert/releases/tag/v2.2.4)

Oracle publishes SHA256 for Instant Client. The rwloadsim release API and
Microsoft package/extension indexes also publish SHA256 digests. SQLcl publishes
SHA1 `3b0e930c621b81833162909a8c584e42ead4372d`; the downloaded archive matched,
and its locally calculated SHA256 is pinned. BATS archive SHA256 values were
calculated from the downloaded fixed-tag archives, not publisher signatures.
Python top-level packages are version-pinned; pip resolves their dependencies.
Ubuntu packages receive the distribution's normal security updates.

[SQLcl 26.3 requires Java 17 or 21](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/26.3/sqcug/working-sqlcl.html).
The image installs OpenJDK 21 JRE from Ubuntu. SQLcl's launcher still mentions
Java 11, but that launcher message is not the supported-runtime requirement.
SQLcl 26.3.1 was executed successfully with OpenJDK 21.

Ubuntu 24.04 supplies `libaio.so.1t64`, while SQL*Plus and rwloadsim need
`libaio.so.1`. The playbook creates the explicit compatibility link and runs
`ldconfig`. The verified rwloadsim archive already has root `bin/` and `lib/`
directories: it must not be extracted with `--strip-components=1`.

## NVMe drivers and Oracle client compatibility

[Microsoft's NVMe guidance](https://learn.microsoft.com/azure/virtual-machines/nvme-linux)
requires boot-ready drivers, persistent disk identifiers and a 240-second IO
timeout. Ubuntu 24.04 is a
[supported NVMe image](https://learn.microsoft.com/azure/virtual-machines/enable-nvme-interface);
the pinned marketplace image explicitly advertises `SCSI, NVMe`.

The playbook installs the signed distribution `linux-azure` kernel,
`initramfs-tools` and `nvme-cli`, includes `nvme` and `nvme_core` in initramfs,
sets `nvme_core.io_timeout=240` in modprobe/GRUB and regenerates the boot files.
It rejects enumerated `/dev/sd*`, `/dev/hd*` and `/dev/nvme*` entries in fstab.
Use UUID, LABEL or persistent `/dev/disk` identifiers instead.

Packer reboots after provisioning. The
[post-reboot check](scripts/verify-nvme.sh) requires an actual NVMe root disk,
the running timeout, initramfs drivers and working Oracle client binaries.
It matches the root filesystem's major/minor identifier to `lsblk` using raw
output, without relying on `/dev/block` aliases or padded display columns.
Drivers built into the running kernel do not need separate initramfs modules.
Failures prevent image generalization. No disk formatting or data-disk
migration is performed. The gallery definition advertises
`DiskControllerTypes=SCSI,NVMe`; participant VMs explicitly select NVMe.

No storage-controller-specific Oracle tool changes were identified:

* [Instant Client and SQL*Plus](https://docs.oracle.com/en/database/oracle/oracle-database/26/lacli/installing-oracle-instant-client/about-oracle-instant-client.html)
  provide network connectivity to a remote database.
* [SQLcl](https://docs.oracle.com/en/database/oracle/sql-developer-command-line/26.3/sqcug/working-sqlcl.html)
  uses Java/JDBC; Java 21 remains installed.
* [python-oracledb Thick mode](https://python-oracledb.readthedocs.io/en/latest/user_guide/initialization.html)
  uses the installed Instant Client for the BaseDB Native Network Encryption
  and Data Integrity requirements. Workshop SQL scripts initialize this mode
  explicitly; Thin mode cannot satisfy that database requirement.
* [rwloadsim/connping](https://github.com/oracle/rwloadsim)
  require an Oracle Client environment and access to a database.

These are client VMs, not local Oracle database/ASM hosts. Existing versions,
library paths, libaio compatibility and connection settings remain unchanged.
This is compatibility research, not Oracle certification of Ubuntu or a
completed live BaseDB SQL test.

## Probe and login behavior

The image includes Python 3.12, the thin-mode Oracle driver, BATS with helpers
under `/opt/bats-support` and `/opt/bats-assert`, Azure CLI with a system-wide
Oracle extension, `dig`, `nc`, `curl`, `jq`, and other network diagnostics.

The driver lives in `/opt/oracle/python`. A system Python `.pth` file exposes
its packages to `/usr/bin/python3`, including root Azure Run Command probes.
OCI CLI has its own `/opt/oci-cli` virtual environment. No system pip override
or `--break-system-packages` is used.

SQL*Plus uses the dynamic linker cache. rwloadsim, connping, and ociping have
wrappers that set their runtime paths even in non-login shells. Every required
tool is checked before generalization; failures stop the image build.

The Base Database TNS example retains the node's private DNS alias and actual
PDB service name. No ADB wallet, adbping, database credentials, or Azure login
extension is configured. The parent installs `AADSSHLoginForLinux` only after
the deployed VM's network is ready.

## Validate locally without a cloud build

You need Packer 1.16.2 and Azure CLI to build. Ansible runs on the temporary VM,
so local Ansible is only needed for optional playbook syntax checks.
The template pins Azure plugin 2.6.5 and Ansible plugin 1.1.3.
The Azure plugin adds the explicit NVMe controller field. Packer 1.11.2
cannot fetch this release because current plugin binaries are distributed
through HashiCorp releases, not GitHub assets.

```bash
cd infra/packer
packer init .
packer fmt -check oracle-workshop.pkr.hcl
packer validate .
ansible-playbook -i localhost, --syntax-check ansible/oracle-tools.yml
shellcheck scripts/install-oracle-tools.sh
/usr/bin/python3 -m unittest discover -s tests -v
```

From the repository root, also validate the remote entry point:

```bash
ansible-playbook -i localhost, --syntax-check infra/ansible/playbooks/oracle-tools.yml
```

`scripts/install-oracle-tools.sh` installs the toolchain on its local machine.
It is not a read-only validation command.

## Build with your Azure CLI login

> [!WARNING]
> The following commands create billable cloud resources. Run them only after
> deployment approval and gallery creation. Use a new semantic version for
> each image build.

```bash
az login --tenant 8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5
az account set --subscription aca3d6b0-497a-40cc-bdd0-e8e3ef6d8483
test "$(az account show --query tenantId -o tsv)" = 8fd3e0b6-0302-4084-a31f-1dfc5bbd03f5
az sig image-definition show \
  --resource-group rg-workshop-images \
  --gallery-name gal_oracle_workshop \
  --gallery-image-definition oracle-workshop-vm \
  --query '{generation:hyperVGeneration,state:osState,architecture:architecture}'
cd infra/packer
packer init .
packer validate .
packer build -var 'image_version=1.1.0' .
```

No service-principal secret or preexisting CI runner is required. Your Azure
identity needs permission to create temporary Compute/network resources and
publish gallery versions. Review leftover build resources after any failure.
Provision the prerequisite resource groups, gallery, and image definition
through the parent's Bicep deployment before running Packer.

After the gallery is ready, run the read-only capacity/image checks from this directory:

```bash
python3 check_vm_prerequisites.py build
```

PowerShell users can run `./build-image.ps1 -Validate` or
`./build-image.ps1 -Version 1.1.0`. The build wrapper asks for confirmation and
uses the active Azure CLI session.

## Capacity and zone checks

The parent build attempt on 2026-11-08 failed before VM creation with
`SkuNotAvailable` for `Standard_D2s_v5` in France Central. That remains a
regional restriction. The v7 replacement avoids that SKU, not the restriction.

Current metadata reports D2as_v7 and D4as_v7 as regionally allowed with zone 2
support; zone 1 is restricted. The small compatible v7 families and regional
quota have 100 free vCPUs. Seven participants require 14 vCPUs; the temporary
builder requires four. Recheck quotas at execution time.

The earlier GPU proposal had zero compatible family quota. No GPU was created;
the approved v7 build does not require one.

Recheck SKU restrictions, generation support, family quota, and regional
quota with read-only commands:

```bash
python3 check_vm_prerequisites.py build
python3 check_vm_prerequisites.py users
```

> [!IMPORTANT]
> A zone-only restriction is not a regional restriction. The checker permits
> zone 2 when only zone 1 is blocked, but rejects a regional block, an unknown
> restriction, missing NVMe metadata or insufficient quota. A successful check
> does not guarantee instantaneous physical capacity.

## Optional GitHub workflow

`.github/workflows/odaa-build-image.yml` defaults to a hosted `ubuntu-latest`
runner and OIDC authentication only. Set repository variable `AZURE_CLIENT_ID`
using the [new-tenant CI bootstrap](../deployments/README.md#github-oidc-bootstrap).
There is no MSI-login or internal-runner override. The tenant, subscription and
image resource group are fixed in the workflow. Local builds remain independent
of CI.

Run `odaa-deploy-image-gallery.yml` before the first build in a fresh environment.
The build rejects an existing image version before creating billable resources.
Version `1.1.0` is already published; choose a fresh version for a rebuild.
Participant deployments remain pinned to the approved `1.1.0` until their static
image configuration and checks are explicitly updated.

## Costs and licenses

The build uses a `Standard_D4as_v7` VM, temporary disks/network resources, and
gallery storage. Azure usage charges apply; no Oracle database is created.
The gallery version remains billable after the build VM is removed.

Instant Client's included `BASIC_LICENSE` and `SQLPLUS_LICENSE` specify Oracle
Free Distribution, Hosting, and Use Terms and Conditions. SQLcl uses Oracle's
[Free Use Terms](https://www.oracle.com/downloads/licenses/oracle-free-license.html).
Review these licenses and redistribution conditions before publishing or
sharing the image. rwloadsim uses the Universal Permissive License 1.0.
The verified fixed Oracle downloads were accessible without an account,
interactive click-through, or manual terms acceptance. This is not a substitute
for reviewing the applicable license. No paid product purchase is needed for
this toolchain.
