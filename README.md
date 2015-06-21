ArepaLinux Script version 0.1
-----------------------------

ArepaLinux script is a Debian-based script for automated installation of basic
servers, appliances y high-end Debian workstations.

installs, configures and optimizes a Debian system in a few minutes.

Features
--------

- Installs a Debian Jessie (last stable) system
- Clean of all systemd- related packages using Devuan packages

Dependencies
------------

ArepaLinux Script require a Debian netinstall basic with this partition schema:

- Basic Debian netinstall

= Partition Schema
- /boot (Primary, 512MB, ext2|ext3|ext4, active)
- / (ext4)

its also compatible with EFI installations.

This script is released under GPL version 3.0.

Use
---

Options:
  -n, --hostname             specify the name of the debian server
  -r, --role                 role-based script for running in server after installation
  -D, --domain               define Domain Name
  -l, --lan                  define LAN Interface (ej: eth0)
  --packages                 Extra comma-separated list of packages
  --debug                    Enable debugging information

example:

./arepalinux.sh -n box1 -D devel.local -l eth0 --packages screen

Debug Options
-------------

--debug : begin a "step by step" process with comments
--step=N : begin only the step listed with number "N", example:

./arepalinux.sh --step=01

starts APT configuration.

-----

Lynis Hardening Index:

================================================================================
  Hardening index : [90]     [##################  ]
================================================================================
