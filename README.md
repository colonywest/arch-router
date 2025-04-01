# Arch Linux Router

Minimalist network router for a home or small business Internet connection built on the [Arch Linux](https://archlinux.org/) distribution. The scripts in this project will install and configure:

* firewalld and NetworkManager
* ISC Kea DHCP
* Unbound DNS

You provide the hardware and follow the instructions. Need anything beyond what this installs and configures - e.g., self-hosted VPN service, VLANs, routing tables or complicated firewall rules? That's on you.

There is no user-friendly UI here. This will set up an Arch Linux system as a router and perform the initial configuration. Everything else from that point is on you. But if you don't need that additional configuration, then this largely becomes set and forget - like most router setups, actually - with the need to keep the software packages up to date.

## Hardware requirements

The ideal system will have:

* a quad-core or better CPU with
* *only* two (2) Ethernet ports, one each for the WAN and LAN,
* both ports being served by dedicated cards with onboard hardware disabled,
* the LAN port equal or faster than the WAN, and
* the WAN port faster than your Internet connection

### You don't need latest and greatest

You may be surprised by how old of hardware you can get away with. My first custom router was an AMD [A8-7600](https://www.amd.com/en/support/downloads/drivers.html/processors/a-series/a8-series-apu-for-desktops/a8-7600-with-radeon-r7-series.html#amd_support_product_spec) FM2+ APU with 16GB DDR3-1600 (dual channel) running OPNsense. And it easily kept pace with Google Fiber's 2Gb service. But it could not keep up with their 5Gb service, capping out at about 3Gb on throughput tests.

The faster your Internet connection, the faster the platform needs to be. But, again, you don't need latest and greatest. Currently, I'm on Google Fiber's 8Gb service with this hardware configuration:

* **CPU**: Intel Xeon E5-2667 v4 (8-core, 16 thread)
* **RAM**: 16GB (4x4GB, quad-channel) DDR4-2400 Registered ECC
* **WAN**: Intel X540 10GbE RJ45
* **LAN**: Mellanox ConnectX-3 10GbE SFP+

While you don't need the latest and greatest, there are considerations you need to keep in mind.

### Hardware considerations

**CPU**. Quad-core minimum. More cores will, to an extent, be better than faster cores. And more physical cores will be better than less cores with HyperThreading.

**Platform**. ECC RAM and quad-channel support is also recommended. *Everything* the router does lives in RAM, and ECC will better guarantee stability and performance at higher bandwidth requirements.

**RAM**. 16GB recommended, as that should be more than enough for most any home Internet configuration. Dual-channel. Quad-channel if the platform supports it for best performance. And, again, ECC very much recommended where supported since, again, *everything* your router does lives in RAM.

**NICs**. Again dedicated cards will be ideal here. Dual-port cards will give you a leaner setup if you do not have mixed media. If you have mixed media - e.g., RJ45 and optical fiber, such as in my setup above - use a dedicated card for each. Avoid using SFP+ RJ45 modules as they run <font color="red">hot</font> and eat up a lot of power.

## How to proceed

First, clone this repository and copy it off to a USB drive so you have it (and these instructions) handy. Or install `git` and clone the repo to your router when you're ready to do the setup. Your choice. I'm just a README. Not like I'm standing behind you watching how you're doing this, right? Right?

Make sure to have *only* the WAN port plugged in when you begin. Follow the Arch Linux [installation guide](https://wiki.archlinux.org/title/Installation_guide), but don't create a swap partition. If you think you need swap space, you instead need more RAM.

After you install the boot loader, **stop**! Don't exit out of `arch-chroot` yet.

### 1. Initial setup

```
cd /path/to/arch-router
./router_packages.sh
```
The `router_packages.sh` script does a few things:

1. Downloads the needed packages: `firewalld`, `networkmanager`, `unbound`, and `kea`
2. Creates two new firewall zones: WAN and LAN
3. Enables IPv4 forwarding in the kernel
4. Enables `firewalld` and `NetworkManager` so they're running when you reboot

Follow the reboot instructions in the Arch installation guide. Then log back in after the system has rebooted.

### 2. Network connections and firewall zones

Run this command: `nmcli con show`

This should show "Wired connection 1" and "Wired connection 2" along with the loopback "lo" device - and any other network devices you forgot to disable in the UEFI. And only the WAN port and loopback should be listed in <font color="green">green text</font>, since the WAN should, again, be the only interface plugged in. Identify which connections will be the WAN and LAN and rename them before running `configure_interfaces.sh`:

```
# Swap "Wired connection 1/2" if necessary

nmcli con mod "Wired connection 1" connection.id WAN
nmcli con mod "Wired connection 2" connection.id LAN

# Setup the LAN connection and set the firewall zones for both. It'll show an
# error if the connection(s) weren't renamed as expected.

./configure_interfaces.sh
```
**Subnets**: the `configure_interfaces.sh` script will set the LAN port to `192.168.1.1/24`, and your network subnet will be `192.168.1.0/24`. Modify the script to set the LAN port IP address if you want something different.

After this, reboot the system to make sure everything takes.

### 3. DHCP - ISC Kea

[Kea](https://www.isc.org/kea/) is the Internet Systems Consortium's DHCP service. I am only interested in IPv4 on my home network, so if you want or need IPv6, you can read [Kea's documentation](https://kea.readthedocs.io/en/kea-2.6.1/) to set up DHCPv6.

Open `kea-dhcp4.conf` in your text editor of choice. A few things need to be updated:

* `interfaces-config`: Replace `[LAN]` with your LAN interface: e.g., enp6s1.
* `subnet4`:
	* `pools`: Update the IP range to what you want
	* `option-data`: Update the IP addresses if you changed your subnet above

Then run `setup_kea-dhcp4.sh`, which will copy the modified config file to `/etc/kea/` and start the service.

### 4. Sanity check

At this point, you should have a working router, just without the ability to resolve domain names. So now a sanity check.

Connect the LAN port to a switch. Running `ncmli con show`, the LAN port should eventually light up in <font color="green">green text</font>. Then connect a laptop or desktop to the switch. The connected system should get an IP address and you should see the DHCP lease in the leases file at `/var/lib/kea/dhcp4`. You should also be able to ping an external IP address - e.g., `1.1.1.1`.

Retrace your steps above if you're encountering any issues. Double-check the Kea configuration file if the service is failing to start or DHCP isn't working. Double-check the network and firewall configurations along with the various IP address settings in Kea if you're not able to ping an external IP address.

### 5. Unbound DNS

Open `unbound.conf` in your text editor of choice. Settings to update:

* `num-threads`: The default here I've given is 4 threads, which should be more-than-adequate for a home Internet connection. Bump this if you feel necessary.
* `interface`: The "LAN interface" entry must match the IP address set for the LAN connection if you changed the default in the `configure_interfaces.sh` script above.
* `access-control`: change the "192.168.1.0" subnet if necessary.

After this, run `setup_unbound.sh`. This script will copy your modified `unbound.conf` file to `/etc/unbound`, setup `unbound-control`, create a subdirectory called `unbound.conf.d` for additional loose configuration files - e.g., DNS entries for static IP addresses on your network, and enable and start the service.

You can [tune Unbound further](https://unbound.docs.nlnetlabs.nl/en/latest/topics/core/performance.html), but I'll leave that to you if you feel that necessary. Which... it should not be... unless you have a lot of systems on your network just pounding Unbound. In which case, you're likely better off having a separate, dedicated DNS server.

### 6. Another sanity check

At this point, your router setup is... complete. Verify everything is now working as expected by opening a browser and pinging a domain name to ensure DNS name resolution works. You should also be able to open a browser and navigate to any website.

**Validate DNSSEC**. [Browse to this site to validate DNSSEC works](https://www.rootcanary.org/test.html). You can further test it by [following this tutorial](https://www.cyberciti.biz/faq/unix-linux-test-and-validate-dnssec-using-dig-command-line/) from a client Linux machine.

**Speedtest!** Download the [Ookla Speedtest CLI](https://www.speedtest.net/apps/cli) to the router and attempt a speed test from there. If you selected adequate hardware for your Internet connection, and you're connecting to a good server, the speed test should saturate your Internet connection without issue. Then be sure to do the same from a client machine with an adequate connection.

## Going forward

**Package updates**. Obviously you need to keep the installed packages up to date for the sake of security. About once a month should be fine, but do keep an eye out for security bulletins as well to know when you may need to update...  a little sooner.

**Root hints**. And run the `update_hints.sh` script as well whenever you update packages. It's rare that the root DNS servers list changes that often, but always best to stay on top of it.

## Syncing DHCP leases to Unbound

So let's talk about the elephant in the room: syncing DHCP leases with Unbound. Why does this package not include it?

Let's ask a better question: do you really need it? It's a nice-to-have, but there are alternatives that, frankly, work better and aren't nearly as error-prone as trying to keep the leases synced. Since it's a background process that OPNsense uses to do this. You can see that in their [source repository](https://github.com/opnsense/core).

Alternatives to doing this include:

1. [Multicast DNS](https://en.wikipedia.org/wiki/Multicast_DNS#:~:text=Multicast%20DNS%20(mDNS)%20is%20a,Domain%20Name%20System%20(DNS).) (mDNS)
2. static IP addresses
3. [DHCP reservations](https://kb.isc.org/docs/what-are-host-reservations-how-to-use-them)

The latter two are what I use in combination since it doesn't require additional software to get it working. I have a static IP address on a few systems on my network - e.g., IP-KVM on my rack, for example - where I need them accessible if the router is down for a significant time. And I use DHCP reservations for everything else where I need the DNS name. Then for those hosts that need it, I have a `.conf` file - one per host -  in the `unbound.conf.d` directory that looks like this:
```
local-data: "[hostname]. A [IPv4]"
```

This is, frankly, a lot less likely to cause problems, such as a sync delay or failure from an intermediate service. And it survives the router being rebooted without issue. And it's the easier option to get working since it doesn't require anything not already readily provided by the software packages being installed.

If you really, really need DHCP and DNS synchronization, use [dnsmasq](https://wiki.archlinux.org/title/Dnsmasq) in place of Kea and Unbound. Just bear in mind that dnsmasq is only a DNS *forwarder*, not a DNS *resolver*, meaning DNS resolutions from your client machines will require extra hops.

## Copyright and License

Copyright &copy; 2025 - Kenneth Ballard.

Licensed under the  [Apache License, Version 2.0](http://www.apache.org/licenses/LICENSE-2.0)  (the "License"); you may not use this file except in compliance with the License.

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

This project is not endorsed, licensed, authorized, distributed, supported, or maintained by Arch Linux. All development and responsibility for this project lies entirely with the author. The author of this project is not in any way affiliated with Arch Linux.