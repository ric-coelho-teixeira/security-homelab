# Security Homelab

Personal cybersecurity lab built to practise network security, attack simulation and intrusion detection.

## Goals
- Build a segmented virtual network with a firewall between attacker and target zones
- Run controlled attacks against intentionally vulnerable machines
- Detect these attacks with an IDS and analyse the alerts
- Later: monitor IP media traffic (multicast, SRT) for anomalies, based on my experience in broadcast infrastructure

## Architecture
| Component | Role | Tool |
|---|---|---|
| Hypervisor | Hosts all VMs | VirtualBox (migration to Proxmox VE planned) |
| Firewall / router | Network segmentation | OPNsense |
| Attacker | Offensive testing | Kali Linux |
| Targets | Vulnerable services | Metasploitable 2 (includes DVWA) |
| Detection | Intrusion detection | Suricata, then Wazuh |

See the full design, addressing plan and firewall policy in [Lab architecture](docs/architecture.md).

## Documentation
- [Lab architecture](docs/architecture.md)
- [01 - OPNsense firewall setup](docs/01-opnsense-setup.md)

## Progress
- [x] Repository and documentation structure
- [x] Network diagram and addressing plan
- [x] Hypervisor setup and virtual networks
- [x] OPNsense firewall installed and addressed
- [ ] Kali Linux (attacker) connected
- [ ] Metasploitable 2 (target) and firewall rules
- [ ] Suricata IDS deployment and first alerts

## Disclaimer
All tests are performed in an isolated lab environment that I own. No external systems are targeted.
