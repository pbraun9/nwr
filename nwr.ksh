#!/bin/ksh

bridgenic=eth1
maxrsect=480000
maxwsect=800

showvalues=0
showsparks=1
# 1 strict / 2 relaxed
hideidle=2

showcpu=1
showram=1
showtx=1
showrx=1
showrs=1
showws=1

function bomb {
	print "Error: $@"
	exit 1
}

function requires {
	whence ls >/dev/null || bomb ls executable not found
	whence cat >/dev/null || bomb cat executable not found
	whence grep >/dev/null || bomb grep executable not found
	whence wc >/dev/null || bomb wc executable not found
	whence tput >/dev/null || bomb tput executable not found
	whence tr >/dev/null || bomb tr executable not found
	whence cut >/dev/null || bomb cut executable not found
	whence sed >/dev/null || bomb sed executable not found
	whence awk >/dev/null || bomb awk executable not found
	#whence find >/dev/null || bomb find executable not found

	whence xentop >/dev/null || bomb xentop executable not found
	whence mii-tool >/dev/null || bomb mii-tool executable not found
	whence spark >/dev/null || bomb spark executable not found
	[[ -d fastio/ ]] || bomb need fastio/ folder, ideally as tmpfs
}

function longest {
	lenght=`echo -n $guest | wc -c`
	(( lenght > longest )) && (( longest = lenght ))
	unset lenght
}

function printspaces {
	until (( spaces < 1 )); do
		print ' \c'
		(( spaces = spaces - 1 ))
	done
	unset spaces
}

function startwagon {
	typeset wagoname=$1
	typeset wagonsparse
	(( wagonsparse = 3 - `echo -n $wagoname | wc -c` ))

        if (( was != 1 )); then
                (( spaces = longest - `echo -n $guest | wc -c` + wagonsparse + 1 ))
                printspaces
                print $guest $wagoname \\c
                (( was = 1 ))
        else
                (( spaces = longest + wagonsparse + 2 ))
                printspaces
                print $wagoname \\c
        fi
}

function xentopdiff {
	typeset restype=$1
	typeset xentopfield=$2
	typeset resmax=$3

        #[[ $oldfile = $file ]] && return
        [[ $oldfile = $files ]] && return
        #grep -E "^[[:space:]]*$guest " $file | awk "{print \$$xentopfield}"
        (( newvalue = `grep -E "^[[:space:]]*$guest " $file | awk "{print \\$$xentopfield}"` ))
        (( oldvalue = `grep -E "^[[:space:]]*$guest " $oldfile | awk "{print \\$$xentopfield}"` ))
        (( diff = newvalue - oldvalue ))
        unset newvalue oldvalue
        echo $guest:$diff >> fastio/${restype}diff.$date

        (( diff == 0 && hideidle == 1 )) && return
        unset diff
        typeset tmpfiles=`ls -1tr fastio/${restype}diff.* | tail -$cols`
        values=`grep -E --no-filename "^$guest:" $tmpfiles | cut -f2 -d:`

	#the trick: we first print a max value, and then get rid of it with sed
	#namely the first three chars
        (( `echo $values | sed -r 's/ /+/g'` == 0 && hideidle == 2 )) && return
        typeset restypeup=`echo $restype | tr 'a-z' 'A-Z'`
        startwagon $restypeup
        (( filescount < cols )) && print ' \c'
        (( showvalues == 1 )) && echo $resmax $values
        (( showsparks == 1 )) && spark $resmax $values | sed -r 's/^...//'
        unset values
}

function showram {
	#dom0 does not have tmem hence eats your ram, and also shows MAXMEM(k) "no limit"
	#maybe autoballoon="on" would help to get decent and usable RAM metrics from the host
	[[ $guest = Domain-0 ]] && return
	maxram=`grep -E "^[[:space:]]*$guest " fastio/xentop.$date | head -1 | awk '{print $7}'` # MAXMEM(k)
	values=`grep -E --no-filename "^[[:space:]]*$guest " $files | awk '{print $5}'` # MEM(k)
	startwagon RAM
	(( showvalues == 1 )) && echo $maxram $values
	(( showsparks == 1 )) && spark $maxram $values | sed -r 's/^...//'
	unset maxram values
}

function guests {
        for guest in $guests; do
                (( spaces = longest - `echo -n $guest | wc -c` + 1 ))

		(( showcpu == 1 )) && xentopdiff cpu 3 $maxcpu # CPU(sec)
		(( showram == 1 )) && showram # MEM(k)
		(( showtx == 1 )) && xentopdiff tx 11 $maxnet # NETTX(k)
		(( showrx == 1 )) && xentopdiff rx 12 $maxnet # NETRX(k)
		(( showrs == 1 )) && xentopdiff rs 17 $maxcpu # VBD_RSECT
		(( showws == 1 )) && xentopdiff ws 18 $maxcpu # VBD_WSECT

		(( was = 0 ))
        done; unset guest
}

function header {
	HOSTNAME=${HOSTNAME:-`uname -n`}
	tmp=`xl info 2>&1`
	(( totalram = `echo "$tmp" | grep ^total_memory | cut -f2 -d:` ))
	(( usedram = totalram - `echo "$tmp" | grep ^free_memory | cut -f2 -d:` ))
	unset tmp
	title="$HOSTNAME - CPU $maxcpu sec - RAM $usedram/$totalram MiB - FDX $maxnet Mbits/s"
	(( spaces = ( termcols - `echo -n $title | wc -c` ) / 2 ))
	printspaces
	bold=`tput bold`
	sgr0=`tput sgr0`
	print "$bold $title $sgr0"
}

function main {
	requires

	# 16 cores -> 1600 % -> 20 cpu seconds (test results)
        (( maxcpu = ( `grep ^processor /proc/cpuinfo | tail -1 | cut -f2 -d:` + 1 ) * 100 / 80 ))
	(( maxnet = `mii-tool $bridgenic | cut -f3 -d' ' | sed -r 's/[^[:digit:]]//g'` ))
	#print maxnet is $maxnet
	#read

	rm -f fastio/xentop.* fastio/*diff.* fastio/tmpout
	while true; do
		date=`date +%s`
		file=fastio/xentop.$date

		xentop -f -b -i 1 > $file
		guests=`grep -vE '^[[:space:]]*NAME ' $file | awk '{print $1}'`
		#guests=load2
		#guests=`xl li | sed 1d | awk '{print $1}'`

		longest=0
	        for guest in $guests; do
			longest
		done; unset guest

		(( termcols = `tput cols` ))
		(( cols = termcols - longest - 3 * 2 - 1 ))
		# - 1 so there is a remaining blank col at the end

                filescount=`ls -1tr fastio/xentop.* | wc -l`
                files=`ls -1tr fastio/xentop.* | tail -$cols`
                #eventually takes the only file as oldfile
                oldfile=`ls -1tr fastio/xentop.* | tail -2 | head -1`

		header > fastio/tmpout
		guests >> fastio/tmpout
		clear
		cat fastio/tmpout
		sleep 1
	done

	unset longest spaces maxcpu maxnet
}

main $@

