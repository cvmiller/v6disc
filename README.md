## Synopsis

A shell script to quickly & automatically discovery IPv6 hosts, with the option to ping or run nmap against discovered hosts.


## Motivation

There are two reasons to use `v6disc.sh`

1. Scan an IPv6 network 700,000 times faster than `nmap`
2. Auto Discovery of IPv6 hosts on the network (e.g. for IPAM)

With 18,446,744,073,709,551,616 (2^64) potential addresses on a LAN segment, the old brute force method of scanning every address (e.g. with nnap) quickly becomes impractical. Even with version 7 of `nmap`, scanning a /64 still **takes a week**! `v6disc.sh` scans a /64 less than **2 seconds**.

####IPv6 under the hood
Each IPv6 node joins the multicast IPv6 all_notes group (FF02::1), one only needs to ping6 this group to determine which hosts are on the link. However, that only yields link-local addresses.

Also understanding how SLAAC addresses are formed from MAC addresses, the v6disc script can "guess" the globally routeable addresses of each host.


## Examples

####Help

```
$ ./v6disc.sh -h
	./v6disc.sh - auto discover IPv6 hosts 
	e.g. ./v6disc.sh -D -P 
	-p  Ping discovered hosts
	-i  use this interface
	-L  show link-local only
	-D  Dual Stack, show IPv4 addresses
	-N  Run nmap against discovered host
	-q  quiet, just print discovered hosts
```

#### Auto detecting interfaces and discovering hosts

```
$ ./v6disc.sh 
-- Searching for interface(s)
Found interface(s): eth0
-- INT:eth0 prefixs: 2607:c000:815f:5600 2001:470:1d:489
-- Detecting hosts on eth0 link
fe80::129a:ddff:fe54:b634
fe80::203:93ff:fe67:4362
fe80::211:24ff:fece:f1a
fe80::211:24ff:fee1:dbc8
fe80::224:a5ff:fef1:7ca
fe80::225:31ff:fe02:aecb
fe80::226:bbff:fe1e:7e15
fe80::256:b3ff:fe04:cbe5
fe80::280:77ff:feeb:1dde
fe80::a00:27ff:fe21:e445
-- Discovered hosts
2607:c000:815f:5600:129a:ddff:fe54:b634
2607:c000:815f:5600:203:93ff:fe67:4362
2607:c000:815f:5600:211:24ff:fece:f1a
2607:c000:815f:5600:211:24ff:fee1:dbc8
2607:c000:815f:5600::1
2607:c000:815f:5600:225:31ff:fe02:aecb
2607:c000:815f:5600:226:bbff:fe1e:7e15
2607:c000:815f:5600:256:b3ff:fe04:cbe5
2607:c000:815f:5600:280:77ff:feeb:1dde
2607:c000:815f:5600:a00:27ff:fe21:e445
2001:470:1d:489:129a:ddff:fe54:b634
2001:470:1d:489:203:93ff:fe67:4362
2001:470:1d:489:211:24ff:fece:f1a
2001:470:1d:489:211:24ff:fee1:dbc8
2001:470:1d:489::1
2001:470:1d:489:225:31ff:fe02:aecb
2001:470:1d:489:226:bbff:fe1e:7e15
2001:470:1d:489:256:b3ff:fe04:cbe5
2001:470:1d:489:280:77ff:feeb:1dde
2001:470:1d:489:a00:27ff:fe21:e445
-- Pau
```

#### Using the Link-Local Option
Don't have a global routable prefix on your network. Still want to see how many IPv6 enabled hosts are ready for the IPv6 network? The link-local option, -L, will print only the discovered hosts (shown with Dual Stack option)

```
$ ./v6disc.sh -L -D
-- Searching for interface(s)
Found interface(s): eth0
-- INT:eth0 prefixs: 
-- Detecting hosts on eth0 link
fe80::129a:ddff:fe54:b634	10.1.1.15
fe80::203:93ff:fe67:4362	10.1.1.18
fe80::211:24ff:fece:f1a	10.1.1.12
fe80::211:24ff:fee1:dbc8	10.1.1.14
fe80::224:a5ff:fef1:7ca	10.1.1.1
fe80::225:31ff:fe02:aecb	10.1.1.9
fe80::226:bbff:fe1e:7e15	10.1.1.23
fe80::256:b3ff:fe04:cbe5	10.1.1.122
fe80::280:77ff:feeb:1dde	10.1.1.13
fe80::a00:27ff:fe21:e445	10.1.1.123
-- Pau
```

#### Discovery with Dual Stack
For those networks which are running Dual Stack, there is an option to print IPv4 addresses next to discovered IPv6 hosts.

```
$ ./v6disc.sh -D
-- Searching for interface(s)
Found interface(s): eth0
-- INT:eth0 prefixs: 2607:c000:815f:5600 2001:470:1d:489
-- Detecting hosts on eth0 link
fe80::129a:ddff:fe54:b634	10.1.1.15
fe80::203:93ff:fe67:4362	10.1.1.18
fe80::211:24ff:fece:f1a	10.1.1.12
fe80::211:24ff:fee1:dbc8	10.1.1.14
fe80::224:a5ff:fef1:7ca	10.1.1.1
fe80::225:31ff:fe02:aecb	10.1.1.9
fe80::226:bbff:fe1e:7e15	10.1.1.23
fe80::256:b3ff:fe04:cbe5	10.1.1.122
fe80::280:77ff:feeb:1dde	10.1.1.13
fe80::a00:27ff:fe21:e445	10.1.1.123
-- Discovered hosts
2607:c000:815f:5600:129a:ddff:fe54:b634	10.1.1.15
2607:c000:815f:5600:203:93ff:fe67:4362	10.1.1.18
2607:c000:815f:5600:211:24ff:fece:f1a	10.1.1.12
2607:c000:815f:5600:211:24ff:fee1:dbc8	10.1.1.14
2607:c000:815f:5600::1	10.1.1.1
2607:c000:815f:5600:225:31ff:fe02:aecb	10.1.1.9
2607:c000:815f:5600:226:bbff:fe1e:7e15	10.1.1.23
2607:c000:815f:5600:256:b3ff:fe04:cbe5	10.1.1.122
2607:c000:815f:5600:280:77ff:feeb:1dde	10.1.1.13
2607:c000:815f:5600:a00:27ff:fe21:e445	10.1.1.123
2001:470:1d:489:129a:ddff:fe54:b634	10.1.1.15
2001:470:1d:489:203:93ff:fe67:4362	10.1.1.18
2001:470:1d:489:211:24ff:fece:f1a	10.1.1.12
2001:470:1d:489:211:24ff:fee1:dbc8	10.1.1.14
2001:470:1d:489::1	10.1.1.1
2001:470:1d:489:225:31ff:fe02:aecb	10.1.1.9
2001:470:1d:489:226:bbff:fe1e:7e15	10.1.1.23
2001:470:1d:489:256:b3ff:fe04:cbe5	10.1.1.122
2001:470:1d:489:280:77ff:feeb:1dde	10.1.1.13
2001:470:1d:489:a00:27ff:fe21:e445	10.1.1.123
-- Pau
```

#### Quiet mode for Scripting
A quiet mode for scripting, or integration into your favourite IPAM software

```
$ ./v6disc.sh -q
2607:c000:815f:5600:129a:ddff:fe54:b634
2607:c000:815f:5600:203:93ff:fe67:4362
2607:c000:815f:5600:211:24ff:fece:f1a
2607:c000:815f:5600:211:24ff:fee1:dbc8
2607:c000:815f:5600::1
2607:c000:815f:5600:225:31ff:fe02:aecb
2607:c000:815f:5600:226:bbff:fe1e:7e15
2607:c000:815f:5600:256:b3ff:fe04:cbe5
2607:c000:815f:5600:280:77ff:feeb:1dde
2607:c000:815f:5600:a00:27ff:fe21:e445
2001:470:1d:489:129a:ddff:fe54:b634
2001:470:1d:489:203:93ff:fe67:4362
2001:470:1d:489:211:24ff:fece:f1a
2001:470:1d:489:211:24ff:fee1:dbc8
2001:470:1d:489::1
2001:470:1d:489:225:31ff:fe02:aecb
2001:470:1d:489:226:bbff:fe1e:7e15
2001:470:1d:489:256:b3ff:fe04:cbe5
2001:470:1d:489:280:77ff:feeb:1dde
2001:470:1d:489:a00:27ff:fe21:e445
```


## Installation

Copy `v6disc.sh` into your directory, and run. The script will auto detect interfaces, and run discovery on all IPv6 enabled interfaces.


## Dependencies

Script requires bash, ip, nmap, grep, tr, sed, sort, cut, ping6 and ping (for Dual Stack). Most distros will have these already installed. Tested on OpenWRT (v15.05) after installing bash, ip, and nmap.

## Limitations

The script assumes /64 subnets (as all end stations should be on a /64). Discovers only the SLAAC address (as defined by RFC 4862), and does not attempt to guess the temporary addresses. Only decects hosts on locally attached network (will not cross routers, but can run on OpenWRT router).

Dual Stack option only supports IPv4 subnet masks of /23, /24, /25.


## Contributors

All code by Craig Miller cvmiller at gmail dot com. But ideas, and ports to other languages are welcome. 


## License

This project is open source, under the GPLv2 license (see [LICENSE](LICENSE))

