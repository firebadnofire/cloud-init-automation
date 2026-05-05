# ACCESS.md

## Purpose

This document defines how agents authenticate to and access virtual machines created by cloud-init-automation.

It intentionally documents **mechanism**, not secrets management policy beyond what is required for operation.

---

## SSH Key Location

The agent’s SSH keypair is expected to exist on the host system at:

```
/home/$USER/.ssh/cgpt/cgpt
/home/$USER/.ssh/cgpt/cgpt.pub
```

* `cgpt` → private key
* `cgpt.pub` → public key

The private key must remain on the host and must never be copied into guest systems.

---

## Key Injection into Test VMs

All VMs created by this framework must allow agent access via the above key.

### Preferred Method: cloud-init

The public key should be injected during VM creation using `cloud-init`:

Example:

```yaml
#cloud-config
users:
  - name: testuser
    ssh_authorized_keys:
      - <contents of /home/$USER/.ssh/cgpt/cgpt.pub>
```

This ensures:

* Access is available immediately on boot
* No post-boot mutation is required
* The VM remains reproducible

### Acceptable Alternatives (less preferred)

* Writing the key via `write_files` + manual placement
* Injecting via provisioning scripts inside `runcmd`

These approaches are more fragile and should be avoided unless necessary.

---

## Network Expectations

VMs are typically attached to the libvirt default network:

```
192.168.122.0/24
```

Any VM may receive an address within this range.

### Do NOT:

* Assume a fixed IP
* Scan the subnet blindly

### Correct Method

After allowing the VM time to boot, resolve its address using:

```bash
sudo virsh domifaddr <VMNAME>
```

This provides the authoritative IP assigned by libvirt.

---

## Connection Workflow

1. Start VM:

   ```bash
   ./bring-up.sh <name>
   ```

2. Wait for boot + cloud-init completion

3. Resolve IP:

   ```bash
   sudo virsh domifaddr <name>
   ```

4. Connect:

   ```bash
   ssh -i /home/$USER/.ssh/cgpt/cgpt testuser@<resolved-ip>
   ```

---

## Timing Considerations

* cloud-init runs asynchronously during boot
* SSH may be available before provisioning completes

Agents should:

* wait for VM readiness
* or retry connection with backoff

---

## Security Notes

* The private key must never be copied into the VM
* Public key injection is safe and expected
* VMs are disposable but should still be treated as untrusted environments

---

## Failure Modes

### Key not working

Likely causes:

* public key not injected
* incorrect user
* cloud-init failure

### No IP returned

* VM not fully started
* networking misconfigured

### SSH connection refused

* SSH not yet ready
* provisioning still running

---

## Philosophy

Access is:

* **ephemeral**
* **automated**
* **reproducible**

If access fails, fix the configuration. Do not manually patch running VMs.

---
