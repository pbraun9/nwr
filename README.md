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

CPU power, MAXMEM and NIC speed is evaluated dynamically.  However DISK speed is tricky to determine (in sectors of 512 bytes per second).  Some testing (see below) is advised to correctly define max values for disk performance.

	vi nwr

	bridgenic=ethX
	maxrsect=480000
	maxwsect=800

## Usage

We want to use system's memory instead of expansive disk i/o.  Assuming `/tmp/` is on `tmpfs` already

	mount | grep tmpfs

otherwise

	mkdir /tmp/fastio/
	mount -t tmpfs -o size=2G tmpfs /tmp/fastio/

Start the TUI

	./nwr.ksh

and when finished

	umount /tmp/fastio/

## Acceptance testing

_on some guest_

	apt install -y stress iperf3 hdparm

CPU

	grep ^proc /proc/cpuinfo
	nice stress --cpu 8

RAM (assuming ballooning or TMEM)

	lsmod | grep tmem
	#stress -m 8 --vm-keep
	mkdir -p ram/
	mount -t tmpfs -o size=7168M tmpfs ram/
	dd if=/dev/zero of=ram/ramload bs=1M
	rm -f ram/ramload 
	umount ram/
	rmdir ram/

Note: it shrinks back after a while (few seconds/minutes)

TX - start the server on the load guest

RX - start the server on the host or remote node

	iperf3 -s # server
	iperf3 -c SERVER_ADDRESS # client

RSECT

	hdparm -Tt /dev/xvda1
	dd if=/dev/xvda1 of=/dev/null

WSECT

	dd if=/dev/zero of=lala conv=sync
	rm -f lala

