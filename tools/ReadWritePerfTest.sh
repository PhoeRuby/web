#!/bin/bash

#Define global variables
os_driver=`df | grep -i /boot | awk '{print $1}' | tr -s '1' ' '`

function Usage
{
    more << EOF
Usage: $0 [Option] dev
    Optional option to run fio performance.
      -d, --device   specify a disk to test
      --mixrw        mixed read and write performance test
      --randr        random read performance test
      --randw        random write performance test
      --seqr         sequential read performance test
      --seqw         sequential write performance test
Example:
    $0 --mixrw 
    $0 -d "/dev/sdb" --randr 
    $0 -d "/dev/sdb /dev/sdc" --seqw
EOF
    exit 0
}

function Perf
{
    local selector=$1
    local fileName="$2"
    local logName=`echo $fileName | cut -d / -f 3`
    case $selector in
        mixrw)
            local RW="randwrite"
            for RW in randrw rw
            do
                for BS in 4k 8k 16k 64k 128k 1M
                do
                    for QD in 1 2 4 8 16 32 64 128
                    do
                        for RATIO in 95 80 70 50
                        do
                            fio --direct=1 --ioengine=libaio --time_based=1 --thread=1 \
                                --group_reporting --log_avg_msec=500 --bwavgtime=500 \
                                --size=100% --numjobs=1 --iodepth=$QD --rw=$RW \
                                --rwmixread=$RATIO --bs=$BS --runtime=300 \
                                --filename=$fileName \
                                --name=mixed_seq_read_write_1job_mix"$RATIO"_"$BS"_QD"$QD" 2>&1 | tee -a mixed_seq_read_write_${logName}.log
                        done      
                    done
                done
            done;;
        randr)
            local RW="randread"
            for BS in 4k 8k 16k 32k 64k 128k 256k 512k 1024k
            do
                for QD in 1 2 4 8 16 32 64 128
                do
                    fio --direct=1 --ioengine=libaio --time_based=1 --thread=1 \
                        --group_reporting --log_avg_msec=500 --bwavgtime=500 \
                        --size=100% --numjobs=1 --iodepth=$QD --rw=$RW --bs=$BS \
                        --runtime=600 --filename=$fileName \
                        --name=random_read_1job_"$BS"_QD"$QD" 2>&1 | tee -a random_read_${logName}.log
                done
            done;;
        randw)
            local RW="randwrite"
            for BS in 4k 8k 16k 32k 64k 128k 256k 512k 1024k
            do
                for QD in 1 2 4 8 16 32 64 128
                do
                    fio --direct=1 --ioengine=libaio --time_based=1 --thread=1 \
                        --group_reporting --log_avg_msec=500 --bwavgtime=500 \
                        --size=100% --numjobs=1 --iodepth=$QD --rw=$RW --bs=$BS \
                        --runtime=600 --filename=$fileName \
                        --name=random_write_1job_"$BS"_QD"$QD" 2>&1 | tee -a random_write_${logName}.log
                done
            done;;
        seqr)
            local RW="read"
            for BS in 4k 8k 16k 32k 64k 128k 256k 512k 1024k
            do
                for QD in 1 2 4 8 16 32 64 128
                do
                    fio --direct=1 --ioengine=libaio --time_based=1 --thread=1 \
                        --group_reporting --log_avg_msec=500 --bwavgtime=500 \
                        --size=100% --numjobs=1 --iodepth=$QD --rw=$RW --bs=$BS \
                        --runtime=600 --filename=$fileName \
                        --name=seq_read_1job_"$BS"_QD"$QD" 2>&1 | tee -a seq_read_${logName}.log
                done
            done;;
        seqw)
            local RW="write"
            for BS in 4k 8k 16k 32k 64k 128k 256k 512k 1024k
            do
                for QD in 1 2 4 8 16 32 64 128
                do
                    fio --direct=1 --ioengine=libaio --time_based=1 --thread=1 \
                        --group_reporting --log_avg_msec=500 --bwavgtime=500 \
                        --size=100% --numjobs=1 --iodepth=$QD --rw=$RW --bs=$BS \
                        --runtime=600 --filename=$fileName \
                        --name=seq_write_1job_"$BS"_QD"$QD" 2>&1 | tee -a seq_write_${logName}.log
                done
            done;;
    esac
}

#Receive arguments
if [ "$#" -ne 0 ]; then
    while [ "$1" != "" ]
    do
        case $1 in
            -h|--help)
                Usage;;
            -d|--device)
                shift
                dev_list=$1;;
            --mixrw)
                mode=mixrw;;
            --randr)
                mode=randr;;
            --randw)
                mode=randw;;
            --seqr)
                mode=seqr;;
            --seqw)
                mode=seqw;;
        esac
        shift
    done
fi

if [ "$mode" == "" ]; then
    printf "Invalid action, try '-h/--help' for more information.\n"
    exit 1
fi

if [ "$dev_list" == "" ]; then
    dev_list=`lsscsi -t | grep -vE "usb|${os_driver}" | awk '{print $NF}' | tr -s '-' ' ' | tr -s '\n' ' ' `
    printf "There was no any disk selected, default device are:\n${dev_list}\n\n"
fi

#Main
for e in $dev_list
do
    Perf $mode $e &
done

#Data slice for excel format
#python FioDataParser.py


