#!/bin/bash
show_usage() {
    echo -e "Usage: \n\t$0 <block device>\n"
    echo -e "EG: $0 /dev/sdj\n"
}
if [ $# -lt 1 -o $# -gt 1 ]; then
	show_usage
	exit 0
elif [ "$1" == "-h" ]; then
	show_usage
	exit 0
elif [[ $1 == /dev/* ]]; then
	echo -e "block device $1\n"
else
	show_usage
        exit 0
fi

envLANG=`echo $LANG`
export LANG=en_US.UTF-8

drop_cache(){
	while [ 1 ]
	do
		sleep 5
		if [ -f /tmp/drop_cache ];then
			_meminfo=`cat /proc/meminfo`

			set -- $(echo "$_meminfo" | awk '
			$1 == "MemAvailable:" { memavail += $2 }
			$1 == "MemFree:"      { memfree  += $2 }
			$1 == "Cached:"       { memfree  += $2 }
			$1 == "Buffers:"      { memfree  += $2 }
			$1 == "MemTotal:"     { memtotal  = $2 }
			$1 == "SwapFree:"     { swapfree  = $2 }
			$1 == "SwapTotal:"    { swaptotal = $2 }
			END {
				if (memavail != 0) { memfree = memavail ; }
				if (memtotal != 0) { print int((memtotal - memfree) / memtotal * 100) ; } else { print 0 ; }
			}')
			mem_usage="$1"
			n_mem_usage=$((10#${mem_usage}/1))
			if [ $n_mem_usage -gt 80 ]; then
				echo 3 > /proc/sys/vm/drop_caches
			fi
		else
			return
		fi
	done
}

blk_dev="$1"
_meminfo=`cat /proc/meminfo`

set -- $(echo "$_meminfo" | awk '
$1 == "MemAvailable:" { memavail += $2 }
$1 == "MemFree:"      { memfree  += $2 }
$1 == "Cached:"       { memfree  += $2 }
$1 == "Buffers:"      { memfree  += $2 }
$1 == "MemTotal:"     { memtotal  = $2 }
$1 == "SwapFree:"     { swapfree  = $2 }
$1 == "SwapTotal:"    { swaptotal = $2 }
END {
if (memavail != 0) { memfree = memavail ; }
print memfree;
print 0;
}')

free_mem="$1"
echo -e "free memory:$free_mem KB\n"

cap=`fdisk -l $blk_dev | grep "$blk_dev" | awk '{print $5}'`
#echo -e "$blk_dev cap:$cap bytes\n"

if [ -z $cap ]; then
	exit
fi

###1TB xfs, needs 2GB memory###
need_mem=$((10#${cap}/(512 * 1024)))
 
echo -e "$blk_dev cap:$cap bytes, xfs_repair needs memory:$need_mem KB\n"

n_free_mem=$((10#${free_mem}/1))
n_need_mem=$((10#${need_mem}/1))

if [ ${n_need_mem} -lt ${n_free_mem} ]; then
	echo -e "free memory is enough, there is no need to mkswap\n"
else
	blk_cnt=$((10#${need_mem}/1024))
	echo -e "\n****** begin to dd swapfile ******\n"
	dd if=/dev/zero of=/tmp/swapfile bs=1M count=$blk_cnt
	
	echo -e "\n****** begin to mkswap & chmod ******\n"
	chmod 0600 /tmp/swapfile
	mkswap /tmp/swapfile
	echo -e "\n****** begin to swapon ******\n"
	swapon /tmp/swapfile
	echo -e "\n****** free -m ******\n"
	free -m
	echo -e "\n****** swapon -s ******\n"
	swapon -s
fi

export LANG=$envLANG

echo
read -p "Is all output OK? Are you sure to continue? [y/n] " input

case $input in
	[yY]*)
		if [ -f /tmp/drop_cache ]; then
			rm /tmp/drop_cache
		fi
		touch /tmp/drop_cache
		drop_cache &
		xfs_repair -L $blk_dev
		if [ -f /tmp/swapfile ]; then
			swapoff /tmp/swapfile
			rm /tmp/swapfile
		fi
		rm /tmp/drop_cache
		;;
	[nN]*)
		if [ -f /tmp/swapfile ]; then
			swapoff /tmp/swapfile
			rm /tmp/swapfile
		fi
		exit
		;;
	*)
		echo "Just enter y or n, please."
		if [ -f /tmp/swapfile ]; then
			swapoff /tmp/swapfile
			rm /tmp/swapfile
		fi
		exit
		;;
esac
