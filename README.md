# _No Web Required_

Performance monitoring from the terminal.  
Currently only XEN (as with `xentop`) is supported.  
To be executed on every single node.  

## Prerequisite

tested with

- XEN 4.11
- KSH93
- [spark.bash](https://github.com/holman/spark) and spark.c

preferably spark.c

	wget https://git.zx2c4.com/spark/plain/spark.c
	gcc -o spark spark.c -lm
	cp -i spark /usr/local/bin/

## Configuration

CPU power, MAXMEM and NIC speed is evaluated dynamically.  However DISK speed is tricky to determine (in sectors of 512 bytes per second).  Some testing (see below) is advised to correctly define max values for disk performance.

	vi nwr

	bridgenic=ethX
	maxrsect=480000
	maxwsect=800

## Usage

you might want to use system's memory instead of expansive disk i/o

	mkdir -p fastio/
	mount -t tmpfs -o size=512M tmpfs fastio/

start the TUI

	./nwr

when finished

	umount fastio/

## Acceptance Testing

_on some guest_

CPU

	nice stress --cpu 16

RAM (assuming ballooning or TMEM)

	lsmod | grep tmem
	mkdir -p ram/
	mount -t tmpfs -o size=7168M tmpfs ram/
	dd if=/dev/zero of=ram/ramload bs=1M

TX/RX

	iperf3 -s # server
	iperf3 -c SERVER_ADDRESS # client

RSECT

	hdparm -Tt /dev/xvda
	dd if=/dev/xvda of=/dev/null

WSECT

	dd if=/dev/zero of=lala conv=sync
	rm -f lala

