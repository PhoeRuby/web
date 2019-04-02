#!/bin/bash

# define global variables
tmp_cmp1=0
tmp_cmp2=0
filename=$0


# function block
function Usage
{
    more << EOF
Usage: $filename [Option] argv

Options:
  -h, --help           show this help message and exit
  -d, --disk           allocate disk to test

  -a, --action         action type please refer to Action Options
Action Options:
  run                  run fio with fio settings
  checkio              check io status
  checksp              check drive speed rate
  checksmart           check drive raw value via s.m.a.r.t
  checkiomsg           check system device error message
  test-step1           check drive state before hotplug
  test-step2           check drive state after hotplug
  test-step3           check drive state after fio
EOF
    exit 0
}

function SmartCheck
{
    local cmp_data=0
    smartctl -A $letter > smartctl.log
    for e in "$@"
    do
        raw_value=`smartctl -A $letter | grep -iE "^${e}\s" | awk '{print $10}'`
        tmp=`smartctl -A $letter | grep -iE "^${e}\s" `
        printf "$tmp\n"
        if [ $raw_value -ne 0 ]; then
            printf "ERROR: error drive raw value found.\n"
            exit 1
        fi
        local cmp_data=$(( $cmp_data + $raw_value ))
    done
    return $cmp_data
}

function IOCheck
{
    local dltr=`basename $letter`
    iostat -xm > iostat.log
    util=`cat iostat.log | grep $dltr | awk '{print $14}' | awk -F\. '{print $1}'`
    cat iostat.log | grep $dltr
    if [ $util -ne 100 ]; then
        printf "ERROR: util percent must equals 100.\n"
        exit 1
    fi
}

function SPCheck
{
    if [ ! -f lsiutil.x86_64 ]; then
        printf "ERROR: tool lsiutil.x86_64 not found.\n"
        exit 1
    fi
    chmod +x lsiutil.x86_64
    ./lsiutil.x86_64 > lsiutil.log << EOF
1
16
EOF
    # parse data
    sas_addr=`lsscsi -g -t | grep $letter | awk '{print $3}' | awk -F0x '{print $2}'`
    handle=`cat lsiutil.log | grep $sas_addr | awk '{print $5}'`
    speed=`cat lsiutil.log | grep $handle | grep -v $sas_addr | awk '{print $9}'`
    more << EOF
SAS Address:  $sas_addr
Handle:       $handle
Speed:        $speed
EOF
    if [ "$speed" == "0.0" ]; then
        printf "ERROR: speed rate error.\n"
        exit 1
    else
        printf "drive speed test O.K.\n"
    fi
}

function IOMsgCheck
{
    dmesg | grep -i "i/o" | grep -iE "error|fail"
    err_num=`dmesg | grep -i "i/o" | grep -iE "error|fail" | wc -l`
    if [ $err_num -ne 0 ]; then
        printf "ERROR: error I/O message found.\n"
        exit 1
    else
        printf "No any error I/O message.\n"
    fi
}

function checkcase1
{
    # step1, run fio before hotplug
    fio --direct=1 --ioengine=libaio --time_based=1 --end_fsync=1 --group_reporting \
        --log_avg_msec=60000 --bwavgtime=60000 --numjobs=1 --iodepth=32  --rw=randrw \
        --rwmixread=50 --bs=4k --runtime=24h --filename=${letter} --name=`basename ${letter}` &
    sleep 5

    # step2, check IO status
    IOCheck

    # step3, check smart record cmp1
    SmartCheck "  5" 197 199
    tmp_cmp1=$?
    echo $tmp_cmp1 > smart_compare_data_1
    echo `lsblk | awk '{print $6}' | wc -l` > total_disk_num

    return 0
}

function checkcase2
{
    # step1, clear device message
    dmesg -c

    # step2, check disk number
    disk_num_before=`cat total_disk_num`
    disk_num_after=`lsblk | awk '{print $6}' | wc -l`
    if [ $disk_num_before -eq $disk_num_after ]; then
        printf "ERROR: after hotplug disk number shouldn't be the same.\n"
        exit 1
    fi

    # step3, check error IO message
    dmesg > dmesg.log
    IOMsgCheck | tee -a dmesg_after_hotplug.log

    # step4, check speed
    SPCheck

    # step5, check smart record cmp2
    SmartCheck "  5" 197 199
    tmp_cmp2=$?
    echo $tmp_cmp2 > smart_compare_data_2

    # step6, run fio after hotplug
    fio --direct=1 --ioengine=libaio --time_based=1 --end_fsync=1 --group_reporting \
        --log_avg_msec=60000 --bwavgtime=60000 --numjobs=1 --iodepth=32  --rw=randrw \
        --rwmixread=50 --bs=4k --runtime=24h --filename=${letter} --name=`basename ${letter}` &
    sleep 5
}

function checkcase3
{
    # step1, check error IO message
    IOMsgCheck | tee -a dmesg_after_fio.log

    # step2, compare smart value
    tmp_cmp1=`cat smart_compare_data_1`
    tmp_cmp2=`cat smart_compare_data_2`
    if [ $tmp_cmp1 -ne $tmp_cmp2 ]; then
        printf "ERROR: error smart data found, Check with cmd 'smartctl -A /dev/disk'.\n"
        exit 1
    fi
}


# main
# parse arguments
if [ $# -gt 0 ]; then
    while [ "$1" != "" ]
    do
        case $1 in
            -h|--help)
                Usage;;
            -d|--disk)
                shift
                letter=$1;;
            -a|--action)
                shift
                action=$1;;
            * ) printf "Invalid argument, Try '-h/--help' for more information.\n"
                exit 1;;
        esac
        shift
    done
fi

# parse action
case $action in
    run) # run fio to rw drive
         fio --direct=1 --ioengine=libaio --time_based=1 --end_fsync=1 --group_reporting \
             --log_avg_msec=60000 --bwavgtime=60000 --numjobs=1 --iodepth=32  --rw=randrw \
             --rwmixread=50 --bs=4k --runtime=24h --filename=${letter} --name=`basename ${letter}` &
         sleep 5;;
    checkio)
         # check IO status
         IOCheck;;
    checksp)
         # check drive speed
         SPCheck;;
    checksmart)
         # check smart
         SmartCheck "  5" 197 199;;
    checkiomsg)
         # check IO message
         IOMsgCheck;;
    test-step1)
         # check before hotplug
         checkcase1;;
    test-step2)
         # test after hotplug
         checkcase2;;
    test-step3)
         # check after fio
         checkcase3;;
    * )  # invalid arguments
         printf "Invalid argument, Try '-h/--help' for more information.\n";;
esac

