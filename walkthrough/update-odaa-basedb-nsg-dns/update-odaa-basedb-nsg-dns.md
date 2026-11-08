---
title: Understand the central Base Database network and DNS
description: Inspect hub DNS and firewall settings, then validate your isolated client's Oracle connectivity.
---

## Challenge 3: Inspect networking and DNS

[Back to the workshop](../../README.md)

Complete [Base Database creation](../create-odaa-basedb/create-odaa-basedb.md)
first. Record the actual native Oracle hostname, private node IP, PDB service
and listener port. Participants do not modify shared DNS or Network Anchors.

## Inspect your spoke and the hub

For `mhuser1`, inspect `rg-vm-mhuser1` and `vnet-vm-mhuser1`, using
`10.0.1.0/24`. The other six participants have the corresponding numbered
spokes. Each VNet uses the firewall's private IP as its custom DNS server.

In `rg-workshop-hub`, your Reader role lets you inspect:

* Firewall DNS Proxy and its upstream server `10.100.0.132`
* Resolver inbound and outbound endpoints
* The Oracle-domain forwarding ruleset
* The central zone `basedb.workshop.internal` and its hub VNet link
* Firewall rules and hub-to-spoke/Oracle peerings

Your default route and the exact Oracle delegated prefix `192.168.0.0/24`
use the firewall as next hop. There is no direct spoke-to-Oracle peering.
NSGs and the firewall deny traffic between user spokes.

## Understand bidirectional DNS

```text
Participant VM -> firewall DNS proxy -> hub resolver inbound
               -> Oracle forwarding ruleset / resolver outbound
               -> Network Anchor listening endpoint -> Oracle DNS

Oracle DNS -> Network Anchor forwarding endpoint -> hub resolver inbound
           -> central Azure private DNS zone
```

The listening endpoint permits the resolver outbound subnet, not direct
participant DNS requests. Only Oracle domains are forwarded towards Oracle;
the Azure private zone is resolved in the hub and never forwarded back.

The organizer verifies OCI DNS endpoint security and listener ingress rules.
For SQL, permit only the assigned client sources and TCP 1521. Do not change
shared OCI subnet/security-list rules to allow all traffic.

## Verify from your VM

Connect to `vm-mhuser1` using the central Bastion; substitute your participant
number. Use the actual DB hostname rather than an invented alias:

```bash
cat /etc/resolv.conf
dig ACTUAL_ORACLE_HOSTNAME
dig +tcp ACTUAL_ORACLE_HOSTNAME
nc -vz -w 10 ACTUAL_ORACLE_HOSTNAME 1521
```

An OS stub resolver address in `/etc/resolv.conf` is normal. Inspect the VNet
custom DNS setting and use `resolvectl status` to see its upstream server.
Both UDP and TCP DNS results must match the assigned private node IP.

The organizer can verify reverse DNS from the Oracle side by resolving
`vm-mhuser1.basedb.workshop.internal` through Oracle's resolver. Participants
must not bypass the DNS design by querying the listening endpoint directly.

The central zone contains organizer-managed VM records. An optional DB alias
must also be created centrally by an organizer. There are no participant-owned
private DNS zones and no participant DNS Zone Contributor assignments.

## Success criteria

* Your Oracle hostname resolves through the firewall and central resolver
* The result matches your own DB node's private IP
* TCP 1521 reaches your listener
* Another participant's VM is not reachable from your spoke
* You can explain the DNS path in both directions without editing shared settings

A successful TCP probe is not proof of authentication or SQL connectivity.
Continue with [SQL connectivity and performance](../perf-test-odaa-basedb/perf-test-odaa-basedb.md).
