# cloud-init VM Test Harness

This repository provides a small, explicit VM-based test harness built on **libvirt**, **QEMU**, and **cloud-init**. It is designed for repeatable, disposable test environments without relying on virt-manager or any GUI tooling.

The primary use case is testing system-level software in clean environments. The original motivation was a Go-based replacement for systemd-resolved implementing secure DNS transports (DoH, DoT, DoQ), but the tooling is generic.

---

## Design Goals

* Disposable test VMs
* No GUI dependencies
* No virt-manager required
* Reproducible builds from a known base image
* Minimal implicit behavior
* Fast iteration
* CLI-first workflow

The workflow intentionally resembles Docker, but uses full virtual machines instead of containers.

---

## Tested host systems

#### (using included `test` directory, using the Debian's generic cloud images)

* OpenSUSE Tumbleweed Linux ✅
* Asahi Fedora Linux ✅

It is recommended to use the included `test` directory to ensure the system works as intended. If it works, the VM will shut itself down after pulling `curl` from the package manager.

---

## High-Level Workflow

1. Maintain a **read-only base qcow2 image**
2. Create **qcow2 overlays** for each test run
3. Inject configuration via **cloud-init (NoCloud) ISO**
4. Boot using **UEFI** (required)
5. Run tests or setup logic
6. Destroy the VM and all per-run artifacts

Each run starts from a clean environment.

---

## Directory Layout

```
.
├── image-info.conf      # Base image configuration (single source of truth)
├── update.sh            # Update base cloud image
├── bring-up.sh          # Build cloud-init, create overlay, boot VM
├── bring-down.sh        # Tear down VM and clean up artifacts
├── build.sh             # Build cloud-init ISO from a directory
├── LICENSE.md
├── README.md
├── vm1/
│   ├── user-data
│   └── meta-data
└── vm2/
    ├── user-data
    └── meta-data
```

All scripts resolve paths **relative to their own location**, not `$HOME`. This makes execution predictable under sudo, cron, or automation.

---

## Prerequisites

* libvirt
* QEMU/KVM
* virt-install
* xorriso (for ISO creation)
* cloud-init inside the guest image

The host must have hardware virtualization enabled.

---

## Base Image Configuration

Base image details are defined in `image-info.conf`:

```sh
BASE_URL="https://cloud.debian.org/images/cloud/trixie/latest"
IMAGE="debian-13-genericcloud-amd64.qcow2"
```

The resolved base image path is:

```
/var/lib/libvirt/ro-images/<IMAGE>
```

This image is treated as **read-only**. Per-run VMs use qcow2 overlays backed by it.

After updating the base image, all existing overlays created from the previous version must be deleted.

---

## Scripts

### `update.sh`

Optional helper to fetch and update the base cloud image.

Responsibilities:

* Fetch `SHA512SUMS` from the configured `BASE_URL`
* Compare against the locally stored checksum
* Download the qcow2 image only when it has changed

Usage:

```bash
./update.sh
```

This script owns **base image lifecycle only** and does not interact with VMs.

---

### `build.sh`

Builds a NoCloud cloud-init ISO from a directory containing `user-data` and `meta-data`.

Expected structure:

```
<name>/
├── user-data
└── meta-data
```

Usage:

```bash
./build.sh <name>
```

Output:

```
/var/lib/libvirt/cloud-init/<name>.iso
```

This script only generates the ISO and performs no VM operations.

---

### `bring-up.sh`

Creates and boots a disposable VM.

Steps performed:

1. Builds the cloud-init ISO using `build.sh`
2. Destroys and undefines any existing VM with the same name
3. Creates a qcow2 overlay backed by the configured base image
4. Boots the VM using `virt-install`
5. Attaches to the serial console

Usage:

```bash
./bring-up.sh <name>
```

UEFI is explicitly enabled to match virt-manager behavior and avoid BIOS-related boot failures.

---

### `bring-down.sh`

Destroys and cleans up a VM and all associated artifacts.

Typical actions:

* Destroy the running VM (if present)
* Undefine the domain
* Remove the qcow2 overlay
* Remove the cloud-init ISO

Usage:

```bash
./bring-down.sh <name>
```

This leaves the system in a clean state.

---

## cloud-init Usage

cloud-init is used in **NoCloud** mode via an attached ISO.

* `user-data` contains configuration, packages, scripts, or test logic
* `meta-data` defines instance identity

cloud-init runs once on first boot. The VM can be configured to power off automatically after completing tests.

---

## Notes and Pitfalls

* **UEFI is mandatory** for modern Debian cloud images when using `virt-install`
* qcow2 overlays must not outlive their backing image
* Serial console output may be minimal unless kernel parameters are adjusted
* This harness intentionally avoids persistent state

---

## Philosophy

This project favors:

* explicit configuration over hidden defaults
* disposable environments over mutable systems
* reproducibility over convenience

If something breaks, the solution is usually to delete it and start again.

---

## License

See [LICENSE.md](https://pubcode.archuser.org/firebadnofire/cloud-init-automation/raw/branch/main/LICENSE.md).

