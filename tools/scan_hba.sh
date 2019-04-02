#!/bin/bash

HBA_NUM=2
DISK_NUM=0

function GetHBAInfo
{
    local num1=$1
    local num2=$2
    echo -e "${num1}\n64\n${num2}\n\nphyinfo" | lsiutil.x86_64 > /root/OSREBOOT/HBA/HBA${num1}_EXP${num2}_INFO.log
    return 0
}

if [ ! -d /root/OSREBOOT/HBA/ ]; then
    mkdir -p /root/OSREBOOT/HBA/
fi

for i in `seq 1 $HBA_NUM`
do
    #Expander
    for j in `seq 1 2`
    do
        #Logger HBA Info
        GetHBAInfo $i $j
        phy_log=/root/OSREBOOT/HBA/HBA${i}_EXP${j}_INFO.log
        for k in `grep -P '\d+\s+.*\s\w+_\w+' $phy_log | awk '{print $6}'`
        do
            phy_addr=`echo $k | tr -d \_ | awk '{print tolower($1)}'`
            drive=`lsscsi -g -t | grep $phy_addr | awk '{print $4}'`
            drive_num=`lsscsi -g -t | grep $phy_addr | awk '{print $4}' | grep -cP '/dev/sd\w{1,2}'`
            if [ $drive_num -eq 0 ]; then
                continue
            fi
            DISK_NUM=$(( $DISK_NUM + 1 ))
            sas_addr=`lsscsi -g -t | grep $phy_addr | awk '{print $3}' | sed 's,sas:0x,,g'`
            phy_change=`grep -P '\d+\s+.*\s\w+_\w+' $phy_log | grep $k | awk '{print $4}'`
            if [ "$phy_change" != "0x03" -a "$phy_change" != "" ]; then
                echo "Disk $drive phy error count has been changed to $phy_change"
            fi
            #echo "${DISK_NUM}: Disk $drive phy error count value is $phy_change"
        done
    done
done
echo $DISK_NUM
