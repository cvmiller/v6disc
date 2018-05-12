## Synopsis

A shell script to quickly & automatically discover IPv6 hosts, with the option to ping or run nmap against discovered hosts.


## Motivation

There are three reasons to use `v6disc.sh`

1. Scan an IPv6 network 700,000 times faster than `nmap`
2. Auto Discovery of IPv6 hosts on the network (e.g. for IPAM)
3. Quickly figure out what IPv6 is already on your network.

With 18,446,744,073,709,551,616 (2^64) potential addresses on a LAN segment, the old brute force method of scanning every address (e.g. with nnap) quickly becomes impractical. Even with version 7 of `nmap`, scanning a /64 still **takes a week**! `v6disc.sh` scans a /64 less than **5 seconds**.

#### MacOS X support (version 2.0)
MacOS X is BSD based, and does not support the linux `ip` command. By creating a ip command emulator in bash, the `ip`, basic show commands are supported on BSD. The script will detect if it is running on a Mac, and automatically include `ip_em.sh`, the `ip` command emulator script.

#### IPv6 under the hood
Each IPv6 node joins the multicast IPv6 all_notes group (FF02::1), one only needs to ping6 this group to determine which hosts are on the link. Pinging using the host Global Unicast Address (GUA) will yield GUAs in that prefix, including hosts which use DHCPv6. 

As of version 1.3, v6disc no longer guesses SLAAC addresses based on MAC addresses (based on RFC 4862).  The script will also use **avahi** or bonjour (if installed).

With [RFC 7217](https://tools.ietf.org/html/rfc7217) (A Method for Generating Semantically Opaque Interface Identifiers with IPv6 Stateless Address Autoconfiguration (SLAAC)) the GUA is more random (e.g. Mac OSX Sierra, aka 10.12). Because RFC 7217 GUA addresses are not guessable, `v6disc.sh` uses the local GUA to discover them (as of version 1.3)

If multiple interfaces are detected, script will query each interface, good for running on routers (tested on OpenWRT 15.05.1)

#### Why Bash?
Bash is terrible at string handling, why write this script in bash? Because I wanted it to run on my router (OpenWRT), and just about every where else, with the minimal amount of dependencies. It is possible to run Python on OpenWRT, but Python requires more storage (more packages) than just bash.

Added colour headings (as of version 1.1) to make output more readable. Colour can be disabled by piping to cat e.g. `v6disc.sh | cat`

## Examples

#### Help

```
$ ./v6disc.sh -h
	./v6disc.sh - auto discover IPv6 hosts 
	e.g. ./v6disc.sh -D -p
	-p  Ping discovered hosts
	-i  use this interface
	-L  show link-local only
	-D  Dual Stack, show IPv4 addresses
	-N  Scan with nmap -6 -sT
	-q  quiet, just print discovered hosts
```

#### Auto detecting interfaces and discovering hosts

```
$ ./v6disc.sh 
-- Searching for interface(s)
Found interface(s): eth0
-- INT:eth0 prefixs: 2607:c000:815f:5600 2001:470:1d:489
-- Detecting hosts on eth0 link
-- Discovered hosts for prefix: 2607:c000:815f:5600 on eth0
2607:c000:815f:5600:129a:ddff:fe54:b634
2607:c000:815f:5600:203:93ff:fe67:4362
2607:c000:815f:5600:211:24ff:fece:f1a
2607:c000:815f:5600:211:24ff:fee1:dbc8
2607:c000:815f:5600::1
2607:c000:815f:5600:225:31ff:fe02:aecb
2607:c000:815f:5600:226:bbff:fe1e:7e15
2607:c000:815f:5600:256:b3ff:fe04:c8e5
2607:c000:815f:5600:280:77ff:feeb:1dde
2607:c000:815f:5600:a00:27ff:fe21:e445
-- Discovered hosts for prefix: 2001:470:1d:489 on eth0
2001:470:1d:489:129a:ddff:fe54:b634
2001:470:1d:489:203:93ff:fe67:4362
2001:470:1d:489:211:24ff:fece:f1a
2001:470:1d:489:211:24ff:fee1:dbd8
2001:470:1d:489::1
2001:470:1d:489:225:31ff:fe02:aecb
2001:470:1d:489:226:bbff:fe1e:7e15
2001:470:1d:489:256:b3ff:fe04:cbe5
2001:470:1d:489:280:77ff:feeb:1dde
2001:470:1d:489:a00:27ff:fe21:e445
-- Displaying avahi discovered hosts 
2001:470:1d:489:211:24ff:fee1:dbd8       halaconia.local
2001:470:1d:489::46f                     hau.local
fe80::129a:ddff:feae:8166                kukui.local
2001:470:1d:489:4459:8014:e3db:c8fe      xubuntu-VirtualBox.local
-- Pau
```

#### Using autodetection with OUI lookup (v1.5 or later)

If the wireshark.gz OUI file is present, v6disc.sh will automatically look up the OUI (MAC manufacturer) in the listing

```
$ ./v6disc.sh 
WARN: avahi utis not found, skipping mDNS check 
-- Searching for interface(s) 
-- Found interface(s):  eth0 
-- INT:eth0	prefixs: 2001:470:b:b2a 2001:470:db8:101 fdce:5802:8872:0 
-- Detecting hosts on eth0 link 
-- Discovered hosts for prefix: 2001:470:b:b2a on eth0 
2001:470:b:b2a:211:24ff:fee1:dbc8        00:11:24:e1:db:c8    Apple
-- Discovered hosts for prefix: 2001:470:db8:101 on eth0 
2001:470:db8:101::1                      00:24:a5:f1:07:ca    Buffalo
2001:470:db8:101:203:93ff:fe67:4362      00:03:93:67:43:62    Apple
2001:470:db8:101:211:24ff:fece:f1a       00:11:24:ce:0f:1a    Apple
2001:470:db8:101:211:24ff:fee1:dbc8      00:11:24:e1:db:c8    Apple
2001:470:db8:101:226:bbff:fe1e:7e15      00:26:bb:1e:7e:15    Apple
2001:470:db8:101::303                    d4:9a:20:01:e0:a4    Apple
2001:470:db8:101:3e2a:f4ff:fe37:dac4     3c:2a:f4:37:da:c4    BrotherI
2001:470:db8:101:6a1:51ff:fea0:9339      04:a1:51:a0:93:38    Netgear
2001:470:db8:101:b41f:18a3:a97c:4a0c     10:9a:dd:54:b6:34    Apple
-- Discovered hosts for prefix: fdce:5802:8872:0 on eth0 
fdce:5802:8872:0:203:93ff:fe67:4362      00:03:93:67:43:62    Apple
fdce:5802:8872:0:211:24ff:fece:f1a       00:11:24:ce:0f:1a    Apple
fdce:5802:8872:0:211:24ff:fee1:dbc8      00:11:24:e1:db:c8    Apple
fdce:5802:8872:0:3e2a:f4ff:fe37:dac4     3c:2a:f4:37:da:c4    BrotherI
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
fe80::211:24ff:fece:f1a		10.1.1.12
fe80::211:24ff:fee1:dbc8	10.1.1.14
fe80::224:a5ff:fef1:7ca		10.1.1.1
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
-- Discovered hosts for prefix: 2607:c000:815f:5600 on eth0
2607:c000:815f:5600:129a:ddff:fe54:b634	10.1.1.15
2607:c000:815f:5600:203:93ff:fe67:4362	10.1.1.18
2607:c000:815f:5600:211:24ff:fece:f1a	10.1.1.12
2607:c000:815f:5600:211:24ff:fee1:dbc8	10.1.1.14
2607:c000:815f:5600::1					10.1.1.1
2607:c000:815f:5600:225:31ff:fe02:aecb	10.1.1.9
2607:c000:815f:5600:226:bbff:fe1e:7e15	10.1.1.23
2607:c000:815f:5600:256:b3ff:fe04:cbe5	10.1.1.122
2607:c000:815f:5600:280:77ff:feeb:1dde	10.1.1.13
2607:c000:815f:5600:a00:27ff:fe21:e445	10.1.1.123
-- Discovered hosts for prefix: 2001:470:1d:489 on eth0
2001:470:1d:489:129a:ddff:fe54:b634		10.1.1.15
2001:470:1d:489:203:93ff:fe67:4362		10.1.1.18
2001:470:1d:489:211:24ff:fece:f1a		10.1.1.12
2001:470:1d:489:211:24ff:fee1:dbc8		10.1.1.14
2001:470:1d:489::1						10.1.1.1
2001:470:1d:489:225:31ff:fe02:aecb		10.1.1.9
2001:470:1d:489:226:bbff:fe1e:7e15		10.1.1.23
2001:470:1d:489:256:b3ff:fe04:cbe5		10.1.1.122
2001:470:1d:489:280:77ff:feeb:1dde		10.1.1.13
2001:470:1d:489:a00:27ff:fe21:e445		10.1.1.123
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

Copy `v4disc.sh` to the same directory, if you are interested in the Dual Stack option (-D).

Copy `wireshark_oui.gz` to the same directory, if you want MAC OUI lookup enabled.


## Dependencies

Script requires bash, ip, grep, tr, sed, sort, cut, awk, ping6 and ping (for Dual Stack). Most distros will have these already installed. `nmap` is required if using the `-N` option. Tested on OpenWRT (v15.05 and 15.05.1) after installing bash, ip, and nmap.

If avahi utils are detected, `v6disc.sh` will also use *bonjour* to detect hosts (as of version 1.2)



## Limitations

The script assumes /64 subnets (as all end stations should be on a /64). Discovers only the SLAAC address (as defined by RFC 4862), and does not attempt to guess the temporary addresses. Only decects hosts on locally attached network (will not cross routers, but can run on OpenWRT router).

Dual Stack option only supports IPv4 subnet masks of /23, /24, /25.

The `v6disc.sh` script may *not* discover Windows machines which don't respond to a ping6 to multicast address FF02::1

Although MacOS X is supported (as of version 2.0) FreeBSD is **not** supported. There is a bug in the kernel code which prevents the detection mechansim from using a GUA source address.

## Contributors

All code by Craig Miller cvmiller at gmail dot com. But ideas, and ports to other languages are welcome. 


## License

This project is open source, under the GPLv2 license (see [LICENSE](LICENSE))
