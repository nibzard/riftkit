Below is an opinionated “ultimate home lab” setup for **fast, ephemeral, agent-friendly Ubuntu environments** on your **Minisforum UN1290 (i9‑12900HK / 32GB / 1TB NVMe)**, with **easy backup/rollback**, **robustness**, and a workflow that matches what you write about: *paved roads, deterministic entry points, and identity/authority boundaries for agents*. ([Refurbished.Minisforum][1])

---

## The architecture I’d run on your box

You want: fast clones, safe-ish isolation for untrusted code, and a clean “loop runner” workflow.

**Recommended topology (simple + strong enough):**

* **Proxmox VE** on the bare metal (ZFS on your NVMe)
* **One “Bastion/Control” VM** (Ubuntu) where *you* SSH in and run your orchestration + agents
* **N ephemeral “Sandbox VMs”** (Ubuntu clones) where agents do the dangerous work
* **Proxmox Backup Server (PBS)** writing to your **USB 1TB** for encrypted, deduplicated, incremental backups

**Key security move**: Sandboxes get **internet**, but **cannot reach your LAN** (or Proxmox management) unless you explicitly allow it.

**ASCII map**

```
Your laptop
   |
   | SSH
   v
[Bastion VM]  (your tools, opencode/claude, agent runner)
   |
   | SSH (only to sandbox subnet)
   v
[Sandbox VMs...]  (ephemeral clones, agent work)
   |
   | NAT out
   v
Internet

[Proxmox host] (management plane)  <-- NOT reachable from sandboxes
   |
   v
[PBS datastore on USB]
```

This matches your “agents stress test dev stacks” idea: **standardize the environment + interfaces**, don’t rely on tribal knowledge. ([nibzard][2])

---

## Why Proxmox + ZFS for your goals

* **Near-instant provisioning** via **templates + linked clones** (especially good on ZFS/NVMe). Proxmox’s `qm clone` behavior for templates defaults toward linked clones where possible. ([Proxmox VE][3])
* **Fast rollback** via:

  * VM snapshots
  * or **QEMU snapshot mode** (“discard changes on shutdown”) for truly throwaway sandboxes. ([Proxmox VE][4])
* **Real backups** with PBS: incremental + dedup + encryption options, so USB space goes further and restores are sane. ([Proxmox][5])

---

## Step-by-step: “Do this in order” (opinionated)

### Step 0 — BIOS + sanity checks

1. Update BIOS/firmware (Minisforum toolchain).
2. Enable:

   * Intel VT-x
   * Intel VT-d / IOMMU (even if you don’t passthrough today)

*(This keeps options open for future eGPU passthrough.)*

---

## Step 1 — Install Proxmox VE on the NVMe using ZFS

**Choose ZFS (single disk)** for snapshots/clones + compression. Yes, single-disk ZFS isn’t redundancy, but it’s still great for your workflow.

During install:

* Filesystem: **ZFS (RAID0 / single disk)**
* Hostname: something like `pve.home`
* Static IP on your LAN (management IP)

After first boot:

```bash
apt update
apt full-upgrade -y
reboot
```

---

## Step 2 — Proxmox hardening (minimum viable)

You are running hostile-ish code. Don’t leave the management plane floppy.

1. **Create a non-root admin** in Proxmox UI.
2. **Disable password SSH** on the Proxmox host (key-only).
3. Turn on **Proxmox firewall** (datacenter + node), and:

   * Allow Proxmox UI/SSH only from your own IP/VPN range
4. Optional but worth it: enable 2FA for the UI.

*(Goal: even if a sandbox gets owned, it can’t trivially pivot into Proxmox.)*

---

## Step 3 — Networking: give sandboxes internet, block LAN access

### The opinionated choice

* `vmbr0`: your LAN bridge (Proxmox management + Bastion VM)
* `vmbr1`: an **internal-only** bridge for sandboxes (no physical NIC)
* NAT from `vmbr1` → `vmbr0` on the Proxmox host

**Sandbox subnet example:** `10.50.0.0/24`

1. Create `vmbr1` in Proxmox network config (no ports attached).

2. Enable IP forwarding on Proxmox host:

```bash
echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-ipforward.conf
sysctl -p /etc/sysctl.d/99-ipforward.conf
```

3. Add NAT (simple iptables MASQUERADE):

```bash
iptables -t nat -A POSTROUTING -s 10.50.0.0/24 -o vmbr0 -j MASQUERADE
```

4. **Block LAN ranges from sandboxes** (example blocks RFC1918 except DNS/NTP if you want):

```bash
iptables -A FORWARD -s 10.50.0.0/24 -d 192.168.0.0/16 -j REJECT
iptables -A FORWARD -s 10.50.0.0/24 -d 10.0.0.0/8 -j REJECT
iptables -A FORWARD -s 10.50.0.0/24 -d 172.16.0.0/12 -j REJECT
```

**Result**

* Sandboxes can `apt install`, pull models, hit GitHub, etc.
* Sandboxes cannot scan your LAN, can’t hit Proxmox UI, can’t hit NAS, etc.

---

## Step 4 — Create the Bastion/Control VM

Make one “clean” Ubuntu VM on `vmbr0` (LAN) that you always SSH into.

Bastion responsibilities:

* Your dotfiles / tooling
* Runs `opencode` / Claude Code
* Runs your “Ralph loops”
* Has SSH keys to access sandboxes
* Keeps your repo mirrors/cache if you want speed

**Firewall rule idea**

* Sandboxes allow inbound SSH **only** from Bastion’s IP.

---

## Step 5 — Set up backups the right way (PBS → USB)

### Why PBS (vs random rsync of qcow2)

PBS is built for VM backups: **incremental transfer + dedup on datastore + encryption support**, with docs that clearly explain the model. ([Proxmox][5])

### Practical home setup

* Plug in your **USB 1TB**
* Run **Proxmox Backup Server** as either:

  * a small VM on the same Proxmox node, with the USB passed through/mounted
  * (best) a separate tiny machine later, but you said USB is fine for now

Minimum:

* datastore on USB
* nightly backups of:

  * Bastion VM
  * your “golden templates”
  * any long-lived VMs

---

## Step 6 — Build a Ubuntu Cloud-Init template (the foundation of speed)

This is where Proxmox shines for what you want: **spin a fresh Ubuntu in seconds** using cloud images + cloud-init. ([Proxmox VE][6])

### Template build (example)

On Proxmox host:

```bash
# 1) Download Ubuntu cloud image (pick LTS; adjust name as needed)
wget -O ubuntu-cloud.img https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img

# 2) Create VM shell
qm create 9000 --name ubuntu-2404-template --memory 4096 --cores 4 \
  --net0 virtio,bridge=vmbr1

# 3) Import disk to your storage (example assumes local-zfs exists)
qm importdisk 9000 ubuntu-cloud.img local-zfs

# 4) Attach + set VM hardware
qm set 9000 --scsihw virtio-scsi-single \
  --scsi0 local-zfs:vm-9000-disk-0,discard=on,ssd=1,iothread=1

# 5) Add cloud-init drive
qm set 9000 --ide2 local-zfs:cloudinit

# 6) Boot config + guest agent channel
qm set 9000 --boot order=scsi0
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --agent enabled=1

# 7) Convert to template
qm template 9000
```

Proxmox documents cloud-init support and the general approach. ([Proxmox VE][6])

---

## Step 7 — “Ephemeral mode” done properly (two options)

### Option A (my default): Linked clones + auto-destroy

* Clone from template
* Run task
* Collect artifacts/logs
* Destroy VM

Proxmox templates are designed to be cloned; `qm clone` supports linked clones (fast) and full clones. ([Proxmox VE][3])

Example:

```bash
qm clone 9000 101 --name sbx-101 --full 0
qm set 101 --ciuser dev --sshkeys /root/keys/dev.pub
qm start 101
```

### Option B (ultra-ephemeral): QEMU snapshot mode (discard on shutdown)

If you want **“changes disappear when VM stops”**, enable snapshot mode in the VM config (QEMU’s “temporary writes” mode). Proxmox exposes this in `qm.conf` / VM config. ([Proxmox VE][4])

Add to `/etc/pve/qemu-server/101.conf`:

```ini
snapshot: 1
```

Then:

* start VM
* agent runs
* shutdown VM
* disk changes vanish automatically

This is *perfect* for hostile runs, but don’t use it for VMs that need persistence.

---

## Step 8 — Speed tricks that actually matter on 1 NVMe

1. **Bake heavy deps into the template** (don’t install toolchains on every clone).
2. Use **virtio** devices (net + disk) and CPU type **host** for performance.
3. Keep sandboxes small:

   * 4–6GB RAM per sandbox
   * 2–4 vCPU per sandbox
4. Keep a “warm pool”:

   * maintain 1–2 stopped clones ready to start instantly

---

## Step 9 — GPU reality on the UN1290 (and what I’d do instead)

Your UN1290 is **Intel Iris Xe** iGPU. ([Refurbished.Minisforum][1])
Directly giving *multiple VMs* “full GPU access” is usually not the smooth path on iGPUs.

### The setup that works well in practice

Run GPU workloads as a **shared local service** instead of passthrough to every sandbox:

* Create one VM or LXC (call it `inference`) that has the GPU device access
* Run:

  * an inference server (Ollama / llama.cpp server / OpenVINO-based service)
* Sandboxes call it over HTTP on the internal network

Benefits:

* Sandboxes stay more isolated
* You avoid GPU passthrough pain
* You get caching (models loaded once)

If you later add an **eGPU (NVIDIA)**, then you can do real PCI passthrough to a dedicated “GPU VM” (still preferably as a shared service).

---

# Tooling layer: OpenCode / Claude Code + Skills (so agents can do DevOps safely)

You explicitly want the agent to help with DevOps. The trick is: **don’t give the agent “root on Proxmox.” Give it a small set of deterministic skills/tools.**

This mirrors your “paved road / deterministic interfaces” principle. ([nibzard][2])

## Install OpenCode on the Bastion

OpenCode provides install methods (script + npm/bun/pnpm). ([OpenCode][7])

On Bastion:

```bash
npm install -g opencode-ai
# or follow the official install script, but I prefer package-manager installs when possible
```

## Create a “Proxmox Sandbox Skill Pack” (Claude Code style)

Claude Code skills are just `SKILL.md` files with YAML frontmatter, stored under `.claude/skills/…` (project) or `~/.claude/skills/…` (personal). ([Claude Code][8])

### What I would implement as skills (opinionated)

Skills that call *your own wrapper scripts*, not raw `qm`:

1. `/sandbox-new <name> <size>`
2. `/sandbox-destroy <id>`
3. `/sandbox-snapshot-clean <id>`
4. `/sandbox-rollback-clean <id>`
5. `/sandbox-run <id> <command>` (exec via SSH and capture logs)
6. `/sandbox-export-artifacts <id>` (rsync logs + diff bundle)

### Why wrapper scripts?

Because wrappers can enforce:

* allowed VMID ranges
* allowed templates
* naming conventions
* network placement
* mandatory logging
* “no LAN access” guarantees

…and they can implement your **approval gates**.

That directly matches your lesson from the “agent filed an issue as me” incident: tools need **authority boundaries**, not just capability. ([nibzard][9])

---

## Identity + credential boundaries (non-negotiable for your use case)

From your own write-up: the failure mode isn’t “agent writes bad code,” it’s “agent performs public actions as you.” ([nibzard][9])

### My opinionated rules

1. **No personal GitHub token inside sandboxes.**
2. If sandboxes need git push:

   * use a **bot account**
   * repo-scoped token
   * no org-admin scopes
3. External actions (issue filing, PRs to other repos, publishing packages):

   * default **draft only**
   * require explicit human “publish” step

This is exactly the “agents can draft; humans publish” gating you described. ([nibzard][9])

---

# Riftkit: where it fits, and how I’d improve it

## Where it fits in this setup

Your site describes **riftkit** as “AI-focused dotfiles for remote VM development… optimized for Claude Code, Amp, and modern CLI tools.” ([nibzard][10])

That makes it a great candidate for the **“golden template bake”** step:

* Boot a VM from the base template once
* Install riftkit + your baseline tools
* Shut down
* Convert that VM into **`agent-template`**
* All sandboxes clone from that

This turns “setup time” into “template refresh time.”

## Improvements I’d propose (high leverage for agent sandboxes)

Even without changing the philosophy, I’d add:

1. **A non-interactive “agent mode” install**

   * `riftkit install --profile agent --yes`
   * deterministic output, strict exit codes (agent-friendly)

2. **Version pinning / lockfile behavior**

   * Agents hate “latest changed.”
   * A single `riftkit.lock` (or similar) makes runs reproducible.

3. **Built-in “dangerous tools” guardrails**

   * install `gh`, but default to:

     * no auth
     * or bot-only auth
   * add aliases/wrappers that force “draft only” on external actions

4. **A “doctor” command**

   * `riftkit doctor` prints:

     * missing deps
     * versions
     * whether environment matches the contract

That directly supports your “machine-readable dev environment contract” theme. ([nibzard][2])

---

# A concrete operating workflow (what you do day-to-day)

### 1) Start your loop

* SSH into Bastion
* `sandbox-new feature-x medium`
* agent runs inside sandbox
* logs + diffs streamed back to Bastion

### 2) Review gate

* agent must produce:

  * patch/diff bundle
  * test output
  * a short “what changed” report
* you approve merge/push

### 3) Revert

* either destroy sandbox VM
* or shutdown (if using snapshot-discard mode)

### 4) Backup (nightly)

* PBS job backs up:

  * Bastion VM
  * templates
  * any stateful service VMs (like inference)

---

## Final opinionated checklist (copy/paste goals)

If you do only 10 things, do these:

1. Proxmox on ZFS (single disk is fine)
2. Bastion VM on LAN
3. Sandbox subnet on internal bridge + NAT out
4. Block RFC1918/LAN access from sandboxes
5. Ubuntu cloud-init template
6. “Agent template” baked with tools (riftkit fits here) ([nibzard][10])
7. Linked clones for speed ([Proxmox VE][3])
8. QEMU snapshot mode for throwaway runs ([Proxmox VE][4])
9. PBS → USB for real backups ([Proxmox][5])
10. Separate identities + approval gates for any public actions ([nibzard][9])

---

If you want, I can also draft:

* a **ready-to-drop `sandboxctl`** bash script (create/clone/start/destroy + log collection),
* a **`.claude/skills/` pack** with 5–10 skills that wrap `sandboxctl` (structured exactly per the Claude Code skills spec), ([Claude Code][8])
* and a “golden template bake” checklist that turns a fresh Ubuntu cloud image into your standardized agent VM in one pass.

[1]: https://refurbished.minisforum.com/products/minisforum-un1265?srsltid=AfmBOopA0DeHr5uQglSMY1NliRlk0_Bj4njFmeSUmR9i4G41h87pzp6O "https://refurbished.minisforum.com/products/minisforum-un1265?srsltid=AfmBOopA0DeHr5uQglSMY1NliRlk0_Bj4njFmeSUmR9i4G41h87pzp6O"
[2]: https://www.nibzard.com/agent-stress-test/?utm_source=tldrnewsletter "https://www.nibzard.com/agent-stress-test/?utm_source=tldrnewsletter"
[3]: https://pve.proxmox.com/pve-docs/qm.1.html "https://pve.proxmox.com/pve-docs/qm.1.html"
[4]: https://pve.proxmox.com/wiki/Manual%3A_qm.conf "https://pve.proxmox.com/wiki/Manual%3A_qm.conf"
[5]: https://www.proxmox.com/en/products/proxmox-backup-server/features "https://www.proxmox.com/en/products/proxmox-backup-server/features"
[6]: https://pve.proxmox.com/wiki/Cloud-Init_Support "https://pve.proxmox.com/wiki/Cloud-Init_Support"
[7]: https://opencode.ai/docs/ "https://opencode.ai/docs/"
[8]: https://code.claude.com/docs/en/skills "https://code.claude.com/docs/en/skills"
[9]: https://www.nibzard.com/agent-identity "https://www.nibzard.com/agent-identity"
[10]: https://www.nibzard.com/projects "https://www.nibzard.com/projects"

