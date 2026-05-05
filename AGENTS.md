# AGENTS.md

## Project: cloud-init-automation

## Overview

cloud-init-automation is a CLI-first framework for building, executing, and validating **disposable virtual machine environments** using libvirt, QEMU, and cloud-init.

It is designed for:

* System-level software testing
* Reproducible environment validation
* Protocol and network behavior testing
* CI-compatible ephemeral infrastructure

Each run creates a clean VM, executes defined logic, captures results, and destroys all state.

No run depends on a previous run.

---

## Core Principles

### 1. Disposable by Default

All environments are treated as throwaway.

* No persistent mutation
* No manual repair
* Failures are debugged, not patched in-place

If something breaks, destroy and rerun.

---

### 2. Reproducibility Over Convenience

Every run must be:

* Deterministic
* Fully defined by inputs
* Independent of host state (beyond declared config)

Implicit behavior is considered a bug.

---

### 3. Explicit Execution Model

All operations are visible and traceable:

* VM creation
* cloud-init injection
* runtime execution
* teardown

There are no hidden background services or magic orchestration.

---

### 4. Isolation of Concerns

The system is divided into clear layers:

* **Base image lifecycle**
* **VM lifecycle orchestration**
* **Test definition (cloud-init)**
* **Test execution (guest-side scripts)**

These layers must not leak into each other.

---

## Architecture

### Host Layer

Responsible for orchestration.

Components:

* `update.sh` → base image lifecycle
* `build.sh` → cloud-init ISO generation
* `bring-up.sh` → VM creation + boot
* `bring-down.sh` → teardown + cleanup
* `copy-log.sh` → artifact extraction

Key characteristics:

* Uses qcow2 overlays backed by read-only base images
* Uses NoCloud ISO injection
* Uses virt-install for VM creation
* Enforces UEFI boot

Reference: fileciteturn0file1

---

### Guest Layer (cloud-init)

Defined per test suite.

Components:

* `user-data`
* `meta-data`
* optional `include/`

Behavior:

* Executes once at first boot
* Installs dependencies
* Runs test logic
* Emits logs and results

Example pattern:

* mount ISO (`cidata`)
* execute injected scripts

---

### Test Layer

Defines **what is being validated**.

A test suite is a directory:

```
<test-name>/
  user-data
  meta-data
  include/
```

Responsibilities:

* Define environment setup
* Execute validation logic
* Record results
* Fail on incorrect behavior

Example: secure DNS proxy validation

* protocol switching (DoH / DoT / DoQ)
* correctness vs reference resolver
* NXDOMAIN validation
* cache behavior
* concurrency stress

Observed failure example:

* NXDOMAIN incorrectly returned NOERROR fileciteturn0file2

This is considered a **test success** (bug detection), not a failure of the framework.

---

## Execution Flow

1. Base image exists or is updated (`update.sh`)
2. Test directory selected (`<name>/`)
3. cloud-init ISO generated (`build.sh`)
4. Overlay disk created (qcow2)
5. VM launched (`bring-up.sh`)
6. cloud-init executes test logic
7. Logs and results written inside VM
8. Logs optionally extracted (`copy-log.sh`)
9. VM destroyed (`bring-down.sh`)

No state persists between runs except:

* base image
* cached host-side artifacts (optional)

---

## Networking Model

Supports:

* libvirt NAT
* macvtap (bridged)
* dual interface mode

Networking must be explicitly defined in `image-info.conf`.

Assumptions such as fixed gateway IPs (e.g. 192.168.122.1) must be treated as configurable, not hardcoded.

---

## Caching Strategy

Repeated VM creation is network-heavy.

Recommended:

* apt-cacher-ng for package caching

Example usage inside guest:

* HTTP apt proxy configuration

This reduces:

* bandwidth usage
* test runtime

---

## Test Design Requirements

All test suites must:

### 1. Validate correctness, not just success

Bad:

* "it responded"

Good:

* compare against reference
* validate expected RCODE
* verify TTL behavior

---

### 2. Fail loudly

* No silent errors
* No ignored failures

---

### 3. Be self-contained

A test must:

* install its own dependencies
* configure its own environment

---

### 4. Be idempotent within a run

Scripts must not assume partial state.

---

### 5. Emit structured output

Recommended:

* JSONL logs

Example fields:

* timestamp
* protocol
* test name
* success
* latency

---

## What This Is Not

cloud-init-automation is NOT:

* a general-purpose orchestration system
* a long-lived VM manager
* a configuration management tool
* a replacement for Kubernetes or Terraform

It is a **disposable execution harness**.

---

## Extending the System

To add a new test suite:

1. Create a new directory:

```
my-test/
  user-data
  meta-data
  include/
```

2. Define setup and execution in `user-data`
3. Place scripts/configs in `include/`
4. Run:

```
./bring-up.sh my-test
```

No changes to the framework should be required.

If changes are required, the abstraction is wrong.

---

## Failure Philosophy

Failures fall into three categories:

### 1. Framework failure

* VM does not boot
* ISO not generated
* networking broken

These must stop execution immediately.

---

### 2. Environment failure

* package install fails
* dependency missing

These indicate test setup issues.

---

### 3. Test failure

* incorrect program behavior
* mismatched output

These are the desired outcome of the system.

---

## Security Considerations

* VMs run arbitrary test code
* network exposure depends on configuration
* secrets must never be baked into images or test configs

All credentials must be injected at runtime or avoided entirely.

---

## Future Direction

The framework should evolve toward:

* multiple test suites with zero coupling
* CI integration (e.g. Forgejo runners)
* parameterized environments
* failure aggregation and reporting
* resource constraint testing

The goal is not complexity.

The goal is **repeatable, trustworthy validation of system behavior**.

---

## Summary

cloud-init-automation is a minimal, explicit, and reproducible system for:

* building disposable VMs
* executing controlled test logic
* validating system-level behavior
* destroying all state afterward

If a system cannot pass in this environment, it is not reliable.
