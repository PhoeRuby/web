
fio --name=4kB_seq_mix_70-30_1job_QD128 \
    --filename=/dev/nvme0n1 \
    --ioengine=libaio --runtime=60 \
    --direct=1 --thread=1 \
    --numjobs=1 --iodepth=128 \
    --rw=randrw --bs=4k --rwmixread=70 \
    --time_based=1 --size=100% \
    --group_reporting --log_avg_msec=1000 \
    --bwavgtime=1000 --minimal --norandommap=1 \
    --randrepeat=0 --write_iops_log=4kB_seq_mix_70-30_1job_QD128 \
    >> nvme0n1_perf_data.log

