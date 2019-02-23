# _No Web Required_

Performance monitoring from the terminal.  
Currently only XEN (as with `xentop`) is supported.  
To be executed on every single node.  

## Requirements

- tested with XEN 4.11
- tested with KSH93
- tested with [spark.bash](https://github.com/holman/spark) and spark.c

preferably spark.c

	wget https://git.zx2c4.com/spark/plain/spark.c
	gcc -o spark spark.c -lm
	cp -i spark /usr/local/bin/

## Usage

you might want to use system's memory instead of expansive disk i/o

	mkdir -p fastio/
	mount -t tmpfs -o size=512M tmpfs fastio/

get the metrics and start the TUI

	xentop -f -b > fastio/metrics.xentop &
	./nwr

when finished

	jobs
	fg
	^C

