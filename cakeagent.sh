#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/etc/cakeagent

# Make sure we have some auth information
if [ -f /etc/cakeagent/auth.log ]
then
	Authentication=($(cat /etc/cakeagent/auth.log))
else
	echo "Something has gone wrong and we can not find your auth credentials. Please reinstall"
	exit 1
fi

CPU=($(cat /proc/stat | grep -E '^cpu\s'))
TOTAL0=$((${CPU[1]}+${CPU[2]}+${CPU[3]}+${CPU[4]}))
IDLE0=${CPU[4]}

sleep 1

# Get the CPU Speed
CPU=($(cat /proc/stat | grep -E '^cpu\s'))
IDLE1=${CPU[4]}
TOTAL1=$((${CPU[1]}+${CPU[2]}+${CPU[3]}+${CPU[4]}))

IDLE=$((${IDLE1}-${IDLE0}))
TOTAL=$((${TOTAL1}-${TOTAL0}))

USAGE=$((1000*(${TOTAL}-${IDLE})/${TOTAL}))
USAGE_UNITS=$((${USAGE}/10))
USAGE_DECIMAL=$((${USAGE}%10))

checkinterval=1                                                                         
info="/sys/class/net/"                                                               
cd $info                                                                             
for interface in 'eth0'                                                                
do                                                                                   
  rx1=`cat $info$interface/statistics/rx_bytes`                                      
  tx1=`cat $info$interface/statistics/tx_bytes`                                      
 `sleep $((checkinterval))s`                                                            
  rx2=`cat $info$interface/statistics/rx_bytes`                                      
  tx2=`cat $info$interface/statistics/tx_bytes`

  RX=$((($rx2-$rx1)/($checkinterval*1024)))
  TX=$((($tx2-$tx1)/($checkinterval*1024)))
done

# Memory Information
freeMem=`cat /proc/meminfo | grep MemFree | sed -r "s/MemFree:.* ([0-9]+) kB/\1/"`
MemTotal=`cat /proc/meminfo | grep MemTotal | sed -r "s/MemTotal:.* ([0-9]+) kB/\1/"`
cpuUse=`top -b -n1 | grep Cpu | sed -re "s/.*:[ ]+([0-9.]*)%us,.*/\1/"`
# Uptime Information
uptime=$(</proc/uptime)
uptime=${uptime%%.*}
seconds=$(( uptime%60 ))
minutes=$(( uptime/60%60 ))
hours=$(( uptime/60/60%24 ))
days=$(( uptime/60/60/24 ))
# Hard Drive Information
hdd=`df -t xfs -t ext4 --total | grep total | awk '{print $3}'`
thdd=`df -t xfs -t ext4 --total | grep total | awk '{print $2}'`
drives=`df -H -P -B G | grep -vE '^Filesystem|tmpfs|cdrom|nfs|origin' | awk '{ printf  $3 "|" $2 "|" $1 ":"}'`
# Running processes
process=`ps aux | grep -v "]\$" | grep -v "/pod" | awk '{ gsub("%","%%",$0); printf  $1 "|" $2 "|" $3 "|" $4 "|" $5 "|" $6 "|" $11 ":::"}'`
# The data to send
data_to_send="user=${Authentication[0]}&secret=${Authentication[1]}&payload={\"rx\":\"$RX\",\"tx\":\"$TX\",\"process\":\"$process\",\"drives\":\"$drives\",\"ping\":\"$ping\",\"freeMem\":\"$freeMem\",\"MemTotal\":\"$MemTotal\",\"cpuUse\":\"$USAGE_UNITS.$USAGE_DECIMAL\",\"uptime\":\"$uptime\",\"hdd\":\"$hdd\",\"thdd\":\"$thdd\"}"
# Send to StatusCake, with a timeout of 30s

wget -q -o /dev/null -O /etc/cakeagent/cakelog.log -T 30 --post-data "$data_to_send" --no-check-certificate https://agent.statuscake.com
