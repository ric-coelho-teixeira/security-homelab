# OPNsense firewall

OPNsense is the central piece of the lab: it routes and filters all traffic
between the zones, and will later inspect it with Suricata.

- **Version:** OPNsense 26.7 (amd64)
- **Built:** November 2026

## Topology

| Adapter | VirtualBox mode | Network | OPNsense interface | Address | DHCP range |
|---|---|---|---|---|---|
| 1 | NAT | — | `em0` (WAN) | DHCP (10.0.2.15/24) | — |
| 2 | Internal network | `lan_attack` | `em1` (LAN) | 10.10.10.1/24 | .100 - .200 |
| 3 | Internal network | `lan_targets` | `em2` (OPT1) | 10.10.20.1/24 | .100 - .200 |
| 4 | Internal network | `lan_monitor` | `em3` (OPT2) | 10.10.30.1/24 | none |

All adapters use the Intel PRO/1000 MT Desktop model (82540EM), which FreeBSD
names `em`. They are created before installation so that FreeBSD numbers them
in a fixed order. See [`../common/architecture.md`](../common/architecture.md)
for the full design.

## Build

### 1. Download and verify the image

Download the `dvd` image for `amd64` from the
[OPNsense download page](https://opnsense.org/download/). Check its SHA-256
hash against the checksum file published on the mirror **before**
decompressing it:

```powershell
Get-FileHash .\OPNsense-26.7-dvd-amd64.iso.bz2 -Algorithm SHA256
```

Then extract the `.iso` file with 7-Zip.

### 2. Create the virtual machine

[`create-vm.ps1`](create-vm.ps1) creates the VM with `VBoxManage`: 2 vCPU,
2 GB of RAM, a 20 GB dynamically allocated disk, legacy BIOS, audio and USB
disabled, and the four adapters above.

```powershell
.\create-vm.ps1 -IsoPath "D:\Lab\ISO\OPNsense-26.7-dvd-amd64.iso" -BaseFolder "D:\Lab\VMs"
```

### 3. Install

1. Start the VM and log in as `installer` / `opnsense` (this account only
   exists on the live system).
2. Choose the keymap, the **UFS** file system and the 20 GB disk (`ada0`).
3. Set a strong root password (never committed here) and reboot.
4. Remove the ISO from the virtual drive: the boot order puts the optical
   drive before the hard disk.

### 4. Assign IP addresses

From the console menu, option `2) Set interface IP address`, for each
interface:

- answer `n` to DHCP and to IPv6;
- enter the address and the prefix length (`24`) from the table above;
- enable the DHCP server on LAN and OPT1 only;
- keep the web GUI on HTTPS.

### 5. Initial configuration (setup wizard)

Start OPNsense first and wait for the console menu, then start Kali.
Otherwise the DHCP request times out and Kali gets no address (`eth0` is UP
but has no `inet` line). Shut down in the reverse order.

The wizard is in System → Configuration → Wizard.

| Setting | Choice | Why |
|---|---|---|
| Domain | `internal` | `.local` is reserved for mDNS; `.internal` is reserved for private use |
| Timezone | Europe/Paris | Correct timestamps are essential to read logs and rebuild an attack timeline |
| DNS | Unbound as a recursive resolver, DNSSEC enabled | No third-party DNS; DNSSEC checks the signatures of DNS answers |
| WAN | DHCP, block RFC1918 and bogon networks | Drops unsolicited inbound traffic from spoofed or impossible source addresses |
| LAN | 10.10.10.1/24 with DHCP | Static gateway address for the attack zone |
| Multi-WAN optimisation | Disabled | Only one gateway (as advised by the built-in help) |

### 6. Isolate the attack zone (LAN firewall rules)

**Problem.** The default rule "Default allow LAN to any" lets Kali reach any
destination. Because the WAN uses VirtualBox NAT, "any" also includes the
home network: Kali → OPNsense → VirtualBox NAT → Windows host → home router.
"Block RFC1918" on the WAN does not help here, because it only filters
traffic *entering* through the WAN, not traffic leaving the lab.

**Fix.** Block the private address ranges (RFC 1918) from the attack zone,
while still allowing OPNsense itself, the target zone and the Internet.

First, an alias groups the three private ranges under one name
(Firewall → Aliases, type **Network(s)**):

| Alias | Content | Description |
|---|---|---|
| `RFC1918` | `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` | Private networks (RFC 1918) |

Then the rules on the LAN interface (Firewall → Rules, direction *in*, IPv4,
any protocol, source *LAN network*). With the *quick* option, the first rule
that matches wins, so **the order matters**:

| # | Action | Destination | Log | Description |
|---|---|---|---|---|
| 1 | Pass | This Firewall | no | Kali to OPNsense (DNS, ping, GUI) |
| 2 | Pass | OPT1 network | no | Kali to targets |
| 3 | **Block** | `RFC1918` | **yes** | Block lab to private networks (home) |
| 4 | Pass | any | no | Default allow LAN to any rule (Internet) |

- Rule 1 is required because OPNsense's own address (10.10.10.1) belongs to
  the `RFC1918` alias: without it, rule 3 would also block DNS (Unbound runs
  on OPNsense).
- Rule 4 is the existing default rule, kept after the three new ones.
- *Block* silently drops the packets; *Reject* would send a refusal back.

## Checks

### After installation

```
LAN (em1)   -> v4: 10.10.10.1/24
OPT1 (em2)  -> v4: 10.10.20.1/24
OPT2 (em3)  -> v4: 10.10.30.1/24
WAN (em0)   -> v4/DHCP4: 10.0.2.15/24
```

- WAN connectivity, from console option `7) Ping host`: `ping 1.1.1.1`
  returns 3/3 packets, about 18 ms, 0% loss.

### After the setup wizard

- DHCP lease visible in Services → Dnsmasq DNS & DHCP → Leases (hostname
  `kali`, VirtualBox MAC prefix `08:00:27`).
- Kali reaches its gateway, the Internet and resolves domain names.

### Isolation of the attack zone (before / after the LAN rules)

Tests run from Kali with `ping -c 2 <destination>`:

| Destination | Before | After | Rule |
|---|---|---|---|
| OPNsense (10.10.10.1) | replies | replies | 1 |
| Internet (1.1.1.1) | replies | replies | 4 |
| Domain name (kali.org) | replies | replies | 1 (DNS) then 4 |
| **Home router** | **replies** | **100% packet loss** | 3 |

- The blocked packets appear in Firewall → Log Files → Live View, with the
  description of rule 3.
- The configuration was exported before and after the change
  (System → Configuration → Backups). These files are never committed: they
  contain password hashes.
- VirtualBox snapshots: `Post install`, `02 - IP addressing`,
  `03 - Wizard done`, `04 - LAN rules`.

## What I learned

- Interface auto-detection does not work in VirtualBox: virtual cables are
  always connected, so no link change is detected. Interfaces must be
  assigned by name.
- The console wizard writes the configuration only at the end, so `Ctrl+C`
  safely cancels a wrong entry. Always re-read which interface is being
  configured: a wrong choice removes the gateway of a whole zone.
- In the console prompts, the capital letter (`[y/N]`) is the default
  answer when pressing Enter.
- OPT interfaces have no firewall rules by default, so all their traffic is
  blocked (deny by default).
- **Stateful firewall:** blocking private networks on a WAN that is itself
  private (VirtualBox NAT) does not break Internet access, because replies
  match existing states before any rule is checked.
- **Read the help before changing a setting:** the default "Optimize for
  Multiwan" was not suited to a single-gateway setup.
- **DNSSEC depends on time:** signatures have validity dates, so a wrong
  clock breaks name resolution.
- **A protection that has not been tested does not exist:** the "before"
  test showed that the lab was not isolated from the home network, which
  would have allowed lateral movement (MITRE ATT&CK TA0008) from a
  compromised VM.
- **New rules are added at the bottom of the list:** placed after "Default
  allow LAN to any", the block rule would never have matched. Check the
  order before clicking Apply. In OPNsense 26.7, a rule is moved by ticking
  it, then clicking the ← arrow of the rule it must go before.
- **The source port is almost always "any":** clients pick a random
  (ephemeral) source port; only the destination port is fixed.

### 7. Disable IPv6 on the attack zone (defense in depth)

The RFC1918 block rule only covers IPv4. The default rule "Default allow LAN IPv6 to any" was still enabled, so IPv6 traffic would not have been filtered if IPv6 ever became available on the WAN.

- Snapshot taken before the change (`05 - avant IPv6`).
- Rule disabled (not deleted), IPv4 rules unchanged, changes applied.

| Test from Kali | Before | After |
|---|---|---|
| `ping 1.1.1.1` / `ping kali.org` | OK | OK (0% loss) |
| `ping -6 ipv6.google.com` | Network is unreachable | Network is unreachable |

The lab had no IPv6 path before the change (no IPv6 route on Kali), so this test shows the change broke nothing, not that the rule blocks IPv6. IPv6 is now disabled by design, not by accident.
