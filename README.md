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
├── bring-down.sh        # Tear down VM and clean up artifacts
├── bring-up.sh          # Build cloud-init, create overlay, boot VM
├── build.sh             # Build cloud-init ISO from a directory
├── update.sh            # Update base cloud images (optional automation)
├── LICENSE.md
├── README.md
└── test/
    ├── cloud-init.iso   # Example generated ISO (not source)
    ├── meta-data        # cloud-init meta-data
    └── user-data        # cloud-init user-data
```

---

## Prerequisites

* libvirt
* QEMU/KVM
* virt-install
* xorriso (for ISO creation)
* cloud-init inside the guest image

The host must have hardware virtualization enabled.

---

## Base Image

The harness expects a Debian cloud image at:

```
/var/lib/libvirt/ro-images/debian-13-genericcloud-amd64.qcow2
```

This image is treated as **read-only**. Per-run VMs use qcow2 overlays backed by this image.

Updating the base image requires deleting any existing overlays created from the old version.

---

## Scripts

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
3. Creates a qcow2 overlay backed by the base image
4. Boots the VM using `virt-install`
5. Attaches to the serial console

Usage:

```bash
./bring-up.sh <name>
```

UEFI is explicitly enabled to match virt-manager behavior and to avoid BIOS-related boot failures.

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

### `update.sh`

Optional helper script to update the base cloud image.

A typical implementation:

* Fetch the latest SHA512SUMS from Debian
* Compare against a locally stored checksum
* Download the new qcow2 image only if it has changed

After updating the base image, all existing overlays must be deleted.

---

## cloud-init Usage

cloud-init is used in **NoCloud** mode via an attached ISO.

* `user-data` contains configuration, packages, scripts, or test logic
* `meta-data` defines instance identity

cloud-init runs once on first boot. The VM can be configured to power off automatically after completing tests.

---

## Notes and Pitfalls

* **UEFI is mandatory** for modern Debian cloud images when using virt-install
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

See `LICENSE.md`.
