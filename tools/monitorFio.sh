#!/bin/bash

function monitorFio
{
    local threshold=$1
    local valid_times=$2
    counter=0
    err_count=0
    while :
    do
        valid_count=0
        os_drive=`df | grep -i /boot | awk '{print $1}' | tr -s '1' ' ' | awk -F\/ '{print $3}'`
        iostat -xm 1 | tee /tmp/io_stat.log > /dev/null 2>&1 &
        sleep 2
        killall iostat
        sleep 1
        io_log=`grep -b "" /tmp/io_stat.log | grep -A 100 "$(grep -b "Device:" /tmp/io_stat.log | sed '$!d' | awk -F\: '{print $1}')" | awk -F\: '{print $2}'`
        drive_num=`echo "$io_log" | grep -P '(\d+\.\d+\s+){12}' | grep -cvP "loop0|$os_drive"`
        iostat=`echo "$io_log" | grep -P '(\d+\.\d+\s+){12}' | grep -vP "loop0|$os_drive" | tr -s ' ' '_'`
        for e in $iostat
        do
            drive=`echo $e | awk -F\_ '{print $1}'`
            util=`echo $e | awk -F\_ '{print $14}' | awk -F\. '{print $1}'`
            if [ $util -gt $threshold ]; then
                valid_count=$(( $valid_count + 1 ))
                echo "Fio drive: ${drive}, %util: $util is valid."
            else
                echo "Fio drive: ${drive}, %util: $util is invalid, must be over than $threshold"
                err_count=$(( $err_count + 1 ))
            fi
            if [ $err_count -gt 100 ]; then
                echo "Fio drive: ${drive} util monitor test FAIL."
                return 1
            fi
        done
        if [ $valid_count -ge $drive_num ]; then
            counter=$(( $counter + 1 ))
        fi
        if [ $counter -eq $valid_times ]; then
            echo "Fio util monitor test PASS."
            return 0
        fi
        sleep 1
    done
}

#main
monitorFio 10 5

