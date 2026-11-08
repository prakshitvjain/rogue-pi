# rogue-pi

An autonomous drop box for internal network penetration tests. Plug it into an Ethernet Cable, walk away, come back later for the results.

Only run this against a network you own or are explicitly authorized to test. Running this against a network without authorization is illegal.

## What it does

1. Boots, autologins to root on tty1 (see `tty1-autologin-shell-setup.sh`).
2. A cronjob runs `initial_script.sh` every minute, checking for an Ethernet link.
3. Once a link is detected, the cronjob removes itself and hands off to `main.sh`.
4. `main.sh` runs the actual attack chain:
   - discovers the local subnet and sweeps it with `nmap -sn`
   - runs a full service scan (`-sS -sV -sC -p-`) against every live host, with decoys and fragmentation to reduce detection
   - groups hosts as Windows or Linux based on service banners
   - groups hosts by open port, across common service ports
   - starts Responder for LLMNR/NBT-NS poisoning
   - enumerates SMB shares on Windows hosts
   - if a domain controller is found, runs Kerbrute for user enumeration and Impacket's `GetNPUsers` for AS-REP roasting

## Hardware

Raspberry Pi running Kali Linux ARM.

## Output

Scan results, grouped host lists, and any harvested hashes are written to local files on the device. There's no exfil channel for now, the device needs to be physically retrieved to collect results, but the idea in a real attack scenario is that data is exfiltrated and OS is destroyed by itself and device is left behind as a casualty.

## Status

Unfinished. A few known issues in the scripts, no exfil mechanism yet.

## Files

- `tty1-autologin-shell-setup.sh` - configures root autologin on boot
- `initial_script.sh` - cronjob entry point, waits for Ethernet, hands off to main.sh
- `main.sh` - the attack chain
