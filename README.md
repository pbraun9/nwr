# _No Web Required_

![2020-04-28-122156_613x242_scrot.png](i/2020-04-28-122156_613x242_scrot.png)

Performance monitoring from the terminal.  
Currently only XEN (as with `xentop`) is supported.  
To be executed on every single node.  

## Requirements

Make sure you have XEN up and running

	xl info
	xentop -b -i1 | head

Make sure all your guests have [TMEM](https://pub.nethence.com/xen/tmem) well [enabled](https://wiki.xenproject.org/wiki/TMEM).  Otherwise disable RAM from the graphcs by setting `showram=0` in the script.

Make sure you've got KSH93 available on your dom0 (floating point capable).

Get ready for sparkles.  Note there's [spark.bash](https://github.com/holman/spark) as an alternative (untested).

	wget https://git.zx2c4.com/spark/plain/spark.c
	gcc -o spark spark.c -lm
	cp -i spark /usr/local/bin/

## Setup

CPU power, MAXMEM and NIC speed is evaluated dynamically.
However DISK speed is tricky to determine (in sectors of 512 bytes per second).
Some testing is advised to correctly define max values for disk performance.

_domU_

	hdparm -t /dev/xvda1

_dom0_

	vi /etc/nwr.conf

	# underlying physical interface
	bridgenic=eth0

	# echo $(( 1232 * 1024 * 1024 / 512 ))
	# eventually divide again by 2 or 3 as those are shared resources
	(( maxrsect = 2523136 / 2 ))
	(( maxwsect = 2523136 / 2 ))

	# assuming 300 Mbit/s link as a shared resource hence divide by 2 or 3
	maxnet=100

## Usage

We want to use system's memory instead of expansive disk i/o.  Assuming `/tmp/` is on `tmpfs` already

	mount | grep tmpfs

otherwise

	mkdir /tmp/fastio/
	mount -t tmpfs -o size=2G tmpfs /tmp/fastio/

Start the TUI

	screen -S nwr

	cd ~/nwr/
	./nwr.ksh

and when finished

	rm -rf /tmp/fastio/
	#umount /tmp/fastio/

## Acceptance testing

_on some guest_

	apt install -y stress iperf3 hdparm

CPU

	grep ^proc /proc/cpuinfo
	nice stress --cpu 16

RAM (assuming ballooning or TMEM)

	lsmod | grep tmem

	stress -m 16 --vm-keep

	#screen
	#mkdir -p ram/
	#mount -t tmpfs -o size=7168M tmpfs ram/
	#dd if=/dev/zero of=ram/lala bs=1M
	#umount ram/
	#rmdir ram/

Note: it shrinks back after a while (few seconds/minutes)

RSECT

	hdparm -Tt /dev/xvda1
	dd if=/dev/xvda1 of=/dev/null bs=1M count=1024

WSECT

	dd if=/dev/zero of=lala bs=1M count=1024 conv=sync
	rm -f lala

TX (upload)

_assuming you got a server listening on your LAN_

	iperf3 -c IPERF-SERVER

RX (download)

	iperf3 -R -c IPERF-SERVER

## Troubleshooting

	SIOCGMIIPHY on 'guestbr0' failed: Operation not supported

==> point to the underlying interface, not the bridge

## Bugs

depending on the load and how long the xentop iteration takes to complete, we are not exactly dealing with metrics every second,
but rather two or three seconds interval, which messes up the results as those are compared against the defined bandwidth maximum values.

