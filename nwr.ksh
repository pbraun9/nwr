#!/bin/ksh

(( debug = 0 ))

function bomb {
	print error: $@
	exit 1
}

function requires {
	whence awk >/dev/null || bomb awk executable not found
	whence cat >/dev/null || bomb cat executable not found
	whence cut >/dev/null || bomb cut executable not found
	#whence find >/dev/null || bomb find executable not found
	whence free >/dev/null || bomb free executable not found
	whence grep >/dev/null || bomb grep executable not found
	whence ls >/dev/null || bomb ls executable not found
	whence tput >/dev/null || bomb tput executable not found
	whence tr >/dev/null || bomb tr executable not found
	whence sed >/dev/null || bomb sed executable not found
	whence wc >/dev/null || bomb wc executable not found

	whence xentop >/dev/null || bomb xentop executable not found
	#whence mii-tool >/dev/null || bomb mii-tool executable not found
	whence spark >/dev/null || bomb spark executable not found

	if (( sendalert == 1 )); then
		whence mail >/dev/null || bomb mail executable not found
	fi

	#[[ -d /tmp/fastio/ ]] || bomb need /tmp/fastio/ folder, ideally as tmpfs
	mkdir -p /tmp/fastio/
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

function start_alert {
	[[ -z $guest ]] && bomb function start_alert needs guest var
	[[ -z $tmptype ]] && bomb function start_alert needs tmptype var
	[[ -z $tmpmax ]] && bomb function start_alert needs tmpmax var

	if [[ ! -f /tmp/fastio/alert-$guest-$tmptype.lock ]]; then
		touch /tmp/fastio/alert-$guest-$tmptype.lock
		echo $guest $tmptype - $lastvalue / $tmpmax \($percent%\) | mail -s "$guest $tmptype resource alert" $email
	fi
}

function end_alert {
	[[ -z $guest ]] && bomb function start_alert needs guest var
	[[ -z $tmptype ]] && bomb function end_alert needs tmptype
	[[ -z $tmpmax ]] && bomb function end_alert needs tmpmax

	if [[ -f /tmp/fastio/alert-$guest-$tmptype.lock ]]; then
		rm -f /tmp/fastio/alert-$guest-$tmptype.lock
		echo $guest $tmptype - $lastvalue / $tmpmax \($percent%\) | mail -s "$guest $tmptype resource ok" $email
	fi
}

function raise_alert {
	[[ -z $2 ]] && bomb function raise_alert needs two args
	tmptype=$1
	tmpmax=$2

	(( lastvalue = `echo $values | awk '{print $NF}'` ))
	(( debug > 0 )) && echo lastvalue is $lastvalue >> /var/log/nwr.log
	if (( sendalert == 1 )); then
		(( percent = lastvalue * 100 / tmpmax ))
		(( debug > 0 )) && echo percent is $percent >> /var/log/nwr.log
		if (( percent >= 90 )); then
			start_alert
		else
			end_alert
		fi
	fi

	unset lastvalue percent
	unset tmptype tmpmax
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
        echo $guest:$diff >> /tmp/fastio/${restype}diff.$date

        (( diff == 0 && hideidle == 1 )) && return
        unset diff
        typeset tmpfiles=`ls -1tr /tmp/fastio/${restype}diff.* | tail -$cols`
        values=`grep -E --no-filename "^$guest:" $tmpfiles | cut -f2 -d:`

	#the trick: we first print a max value, and then get rid of it with sed
	#namely the first three chars
        (( `echo $values | sed -r 's/ /+/g'` == 0 && hideidle == 2 )) && return
        typeset restypeup=`echo $restype | tr 'a-z' 'A-Z'`
        startwagon $restypeup
        (( filescount < cols )) && print ' \c'
        (( showsparks == 1 )) && spark $resmax $values | sed -r 's/^...//'
        (( debugvalues == 1 )) && echo $guest $restype $values / $resmax >> /var/log/nwr.log

	raise_alert $restype $resmax

        unset values
}

function show_ram {
	#dom0 does not have tmem hence eats your ram and shows MAXMEM(k) "no limit"
	#we do not differenciate dom0_mem vs autoballoon here
	[[ $guest = Domain-0 ]] && return
	#if [[ $guest = Domain-0 ]]; then
	#	maxram=`free --kilo | grep ^Mem: | awk '{print $2}'`
	#else
	#fi
	maxram=`grep -E "^[[:space:]]*$guest " /tmp/fastio/xentop.$date | head -1 | awk '{print $7}'` # MAXMEM(k)
	values=`grep -E --no-filename "^[[:space:]]*$guest " $files | awk '{print $5}'` # MEM(k)
	startwagon RAM
	(( showsparks == 1 )) && spark $maxram $values | sed -r 's/^...//'
	(( debugvalues == 1 )) && echo $guest ram $values / $maxram >> /var/log/nwr.log

	raise_alert ram $maxram

	unset maxram values
}

function show_guests {
        for guest in $guests; do
                (( spaces = longest - `echo -n $guest | wc -c` + 1 ))

		(( showcpu == 1 )) && xentopdiff cpu 3 $maxcpu # CPU(sec)
		(( showram == 1 )) && show_ram # MEM(k)
		(( showtx == 1 )) && xentopdiff tx 11 $maxnet # NETTX(k)
		(( showrx == 1 )) && xentopdiff rx 12 $maxnet # NETRX(k)
		(( showrs == 1 )) && xentopdiff rs 17 $maxrsect # VBD_RSECT
		(( showws == 1 )) && xentopdiff ws 18 $maxwsect # VBD_WSECT

		(( was = 0 ))
        done; unset guest
}

function show_header {
	HOSTNAME=${HOSTNAME:-`uname -n`}
	tmp=`xl info 2>&1`
	(( totalram = `echo "$tmp" | grep ^total_memory | cut -f2 -d:` ))
	#(( usedram = totalram - `echo "$tmp" | grep ^free_memory | cut -f2 -d:` ))
	unset tmp
	title="$HOSTNAME - $maxcpu CPU seconds - $totalram MB - R $maxrsect / W $maxwsect sectors/s - $maxnet Mbit/s"
	(( spaces = ( termcols - `echo -n $title | wc -c` ) / 2 ))
	printspaces
	bold=`tput bold`
	sgr0=`tput sgr0`
	print "$bold $title $sgr0"
}

function main {
	[[ ! -f /etc/nwr.conf ]] && echo could not find /etc/nwr.conf && exit 1
	source /etc/nwr.conf

	[[ -z $bridgenic ]] && bomb bridgenic not defined
	[[ -z $cores ]] && bomb cores not defined
	[[ -z $maxrsect ]] && bomb maxrsect not defined
	[[ -z $maxwsect ]] && bomb maxwsect not defined
	[[ -z $maxnet ]] && bomb maxnet not defined

	# values are per second and we are running the script every 4-5 seconds
	# hence we need to multiply by 5 (more precise than dividing values by 5)
	(( maxcpu = cores * 5 ))
	# maxram is static
	(( maxrsect = maxrsect * 5 ))
	(( maxwsect = maxrsect * 5 ))
	(( maxnet = maxnet * 5 ))

	requires

	# 16 cores -> 1600 % -> 20 cpu seconds (test results)
        #(( maxcpu = ( `grep ^processor /proc/cpuinfo | tail -1 | cut -f2 -d:` + 1 ) * 100 / 80 ))

	rm -f /tmp/fastio/xentop.* /tmp/fastio/*diff.* /tmp/fastio/tmpout
	while true; do
		date=`date +%s`
		file=/tmp/fastio/xentop.$date

		xentop -f -b -i 1 > $file
		guests=`grep -vE '^[[:space:]]*NAME ' $file | awk '{print $1}'`
		#guests=`xl li | sed 1d | awk '{print $1}'`
		#guests=load

		longest=0
	        for guest in $guests; do
			longest
		done; unset guest

		(( termcols = `tput cols` ))
		(( cols = termcols - longest - 3 * 2 - 1 ))
		# - 1 so there is a remaining blank col at the end

                filescount=`ls -1tr /tmp/fastio/xentop.* | wc -l`
                files=`ls -1tr /tmp/fastio/xentop.* | tail -$cols`
                #eventually takes the only file as oldfile
                oldfile=`ls -1tr /tmp/fastio/xentop.* | tail -2 | head -1`

		show_header > /tmp/fastio/tmpout
		show_guests >> /tmp/fastio/tmpout
		clear
		cat /tmp/fastio/tmpout

		# assuming xentop takes about 1 second by itself on a loaded dom0 host
		sleep 4
	done

	unset longest spaces maxcpu maxnet
}

main $@

