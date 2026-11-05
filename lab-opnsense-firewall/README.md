# 01 - OPNsense firewall setup

OPNsense is the central piece of the lab: it routes and filters all traffic between the zones, and will later inspect it with Suricata.

**Version:** OPNsense 26.7 (amd64) - **Date:** November 2026

## 1. Image download and verification

- Image type: `dvd` (ISO installer), architecture `amd64`.
- The SHA-256 hash of the `.iso.bz2` file was checked against the checksum file published on the mirror (`Get-FileHash` in PowerShell) **before** decompression.

## 2. Virtual machine

| Setting | Value | Reason |
|---|---|---|
| Type | BSD / FreeBSD (64-bit) | OPNsense is based on FreeBSD |
| vCPU / RAM | 2 / 2 GB | Room for Suricata packet inspection |
| Disk | 20 GB VDI, dynamically allocated | Grows only with actual data |
| Firmware | Legacy BIOS | EFI / Secure Boot not needed |
| Audio, USB | Disabled | Reduce attack surface |

### Network adapters

All adapters use the Intel PRO/1000 MT Desktop model, which FreeBSD names `em`.

| Adapter | VirtualBox mode | Network | OPNsense interface |
|---|---|---|---|
| 1 | NAT | — | `em0` (WAN) |
| 2 | Internal network | `lan_attack` | `em1` (LAN) |
| 3 | Internal network | `lan_targets` | `em2` (OPT1) |
| 4 | Internal network | `lan_monitor` | `em3` (OPT2) |

All four adapters were created before installation so that FreeBSD numbers them in a fixed order.

## 3. Installation

- Installer account (`installer`) from the live system, French keymap, **UFS** file system (lighter than ZFS; snapshots are handled by VirtualBox).
- The ISO was removed after installation: the boot order (optical before hard disk) would otherwise start the live system again.

## 4. IP addressing (console, option 2)

| Interface | Zone | Address | DHCP range |
|---|---|---|---|
| LAN (`em1`) | LAN_ATTACK | 10.10.10.1/24 | 10.10.10.100 - 10.10.10.200 |
| OPT1 (`em2`) | LAN_TARGETS | 10.10.20.1/24 | 10.10.20.100 - 10.10.20.200 |
| OPT2 (`em3`) | LAN_MONITOR | 10.10.30.1/24 | none (static addresses only) |
| WAN (`em0`) | VirtualBox NAT | DHCP (10.0.2.15/24) | — |

- IPv6 is not used for now.
- The web GUI stays on **HTTPS** (no plain-text administration).

## 5. Verification

- WAN connectivity: `ping 1.1.1.1` from the console - 3/3 packets received, ~18 ms, 0% loss.
- VirtualBox snapshots: `Post install`, `02 - IP addressing`.

## Lessons learned

- Interface auto-detection does not work in VirtualBox: virtual cables are always connected, so no link change is detected. Interfaces were assigned by name.
- The OPNsense console wizard writes the configuration only at the end: `Ctrl+C` cancels a wrong entry safely.
- Always re-read which interface is being configured before validating: a wrong choice would remove the gateway of a whole zone.
- OPT interfaces have no firewall rules by default, so all their traffic is blocked (deny by default). Rules will be written explicitly.

## Next step

Connect Kali Linux to `lan_attack`, check DHCP, routing and DNS, and access the web GUI after verifying the certificate fingerprint.
