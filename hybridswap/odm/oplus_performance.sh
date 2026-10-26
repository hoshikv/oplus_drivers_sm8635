#!/vendor/bin/sh

config="$1"

hybridswap_tool=/product/bin/nandswap_tool
swapfile_path=/data/nandswap/swapfile

log() {
    log -t "oplus_perf" "$1"
}

function hybridswap_setup()
{
    MemTotalStr=$(cat /proc/meminfo | grep MemTotal)
    MemTotal=${MemTotalStr:16:8}

    if [ -f /sys/block/zram0/hybridswap_enable ]; then
        log "hybridswap module loaded, configuring..."

        # Determine zram size based on RAM
        if [ $MemTotal -le 4194304 ]; then
            swap_size_mb=2048
            avail_buffers="300 100 300 256"
        elif [ $MemTotal -le 6291456 ]; then
            swap_size_mb=3072
            avail_buffers="800 500 800 512"
        elif [ $MemTotal -le 8388608 ]; then
            swap_size_mb=3072
            avail_buffers="1000 700 1000 768"
        elif [ $MemTotal -le 12582912 ]; then
            swap_size_mb=4096
            avail_buffers="1400 1000 1400 1024"
        else
            swap_size_mb=5120
            avail_buffers="1400 1000 1400 1024"
        fi

        # Set compression algorithm
        echo lz4 > /sys/block/zram0/comp_algorithm

        # Set disksize if not already set
        current_disksize=$(cat /sys/block/zram0/disksize)
        new_disksize=$((swap_size_mb * 1024 * 1024))
        if [ "$current_disksize" -ne "$new_disksize" ]; then
            log "Setting zram disksize: ${swap_size_mb}MB"
            echo "$new_disksize" > /sys/block/zram0/disksize
        fi

        # Setup memcg parameters
        chmod o+w /sys/block/zram0/hybridswap_* 2>/dev/null

        memcg_root="/dev/memcg"
        if [ -e "/sys/fs/cgroup/memory.swapd_memcgs_param" ]; then
            memcg_root="/sys/fs/cgroup"
        fi

        # App priority levels - more aggressive tiers
        echo "3 0 99 0 0 0 100 399 40 0 0 400 499 30 0 0 " > $memcg_root/memory.swapd_memcgs_param
        echo 400 > $memcg_root/memory.app_score
        echo root > $memcg_root/memory.name

        # Lower thresholds = swapd kicks in earlier
        echo "$avail_buffers" > $memcg_root/memory.avail_buffers
        zram_critical=$((swap_size_mb - 128))
        echo $zram_critical > $memcg_root/memory.zram_critical_threshold

        # Aggressive swapd parameters
        echo 64 > $memcg_root/memory.swapd_max_reclaim_size
        echo "800 30" > $memcg_root/memory.swapd_shrink_parameter
        echo 3000 > $memcg_root/memory.max_skip_interval
        echo 30 > $memcg_root/memory.reclaim_exceed_sleep_ms
        echo 50 > $memcg_root/memory.cpuload_threshold
        echo 48 > $memcg_root/memory.max_reclaimin_size_mb
        echo 60 > $memcg_root/memory.zram_wm_ratio
        echo 256 > $memcg_root/memory.empty_round_skip_interval
        echo 10 > $memcg_root/memory.empty_round_check_threshold
        echo 1 > /sys/block/zram0/hybridswap_loglevel

        # Create swapfile if missing
        if [ ! -f "$swapfile_path" ]; then
            log "Creating ${swap_size_mb}MB swapfile..."
            mkdir -p /data/nandswap
            dd if=/dev/zero of=$swapfile_path bs=1M count=$swap_size_mb 2>/dev/null
            $hybridswap_tool -s1 $swapfile_path
        fi

        # Setup loop device if swapfile exists
        if [ -f "$swapfile_path" ]; then
            loop_device=$(losetup -f -s $swapfile_path 2>&1)
            loop_ret=$?
            if [ $loop_ret -eq 0 ]; then
                log "Loop: $loop_device"
                $hybridswap_tool -l $loop_device
                echo -n "$loop_device" > /sys/block/zram0/hybridswap_loop_device
                echo 1 > /sys/block/zram0/hybridswap_enable
                log "Hybridswap enabled"
            else
                log "Loop failed, enabling swapd only"
                echo 1 > /sys/block/zram0/hybridswap_enable
            fi
        else
            log "No swapfile, enabling swapd only"
            echo 1 > /sys/block/zram0/hybridswap_enable
        fi

        log "Zram: ${swap_size_mb}MB, algo=lz4, wm_ratio=60"
    fi
}

function vm_tune()
{
    MemTotalStr=$(cat /proc/meminfo | grep MemTotal)
    MemTotal=${MemTotalStr:16:8}

    log "Tuning VM parameters..."

    # Higher swappiness = push anon pages to zram earlier
    echo 160 > /proc/sys/vm/swappiness

    # Reclaim slab/pagecache faster
    echo 150 > /proc/sys/vm/vfs_cache_pressure

    # Kernel reclaims earlier (lower = earlier)
    echo 10 > /proc/sys/vm/watermark_scale_factor

    # More aggressive dirty page writeback
    echo 5 > /proc/sys/vm/dirty_ratio
    echo 1 > /proc/sys/vm/dirty_background_ratio
    echo 100 > /proc/sys/vm/dirty_expire_centisecs
    echo 100 > /proc/sys/vm/dirty_writeback_centisecs

    # Disable compaction proactive (reduce CPU overhead)
    echo 0 > /proc/sys/vm/compaction_proactiveness

    # Reduce page cluster for faster swap-in
    echo 0 > /proc/sys/vm/page-cluster

    # Force periodic shrink for 8GB and below
    if [ $MemTotal -le 8388608 ]; then
        log "Low RAM: enabling aggressive force shrink"
        echo 1 > /dev/memcg/memory.force_shrink_anon 2>/dev/null
        echo 1 > /dev/memcg/memory.force_shrink_file 2>/dev/null
        echo 1 > /proc/sys/vm/drop_caches 2>/dev/null
    fi
}

function lowram_device_setup()
{
    MemTotalStr=`cat /proc/meminfo | grep MemTotal`
    MemTotal=${MemTotalStr:16:8}

    Heapminfree=4m
    Heapmaxfree=32m
    Heapstartsize=16m
    Heapsize=512m
    Heapgrowthlimit=256m
    Heaptargetutilization=0.5

    if [ $MemTotal -lt 9437184 ]; then
       Heapminfree=2m
       Heapmaxfree=16m
       Heapstartsize=16m
       Heapsize=512m
       Heapgrowthlimit=384m
       Heaptargetutilization=0.75
    fi

    setprop vendor.oplus.dalvik.vm.heapminfree $Heapminfree
    setprop vendor.oplus.dalvik.vm.heapmaxfree $Heapmaxfree
    setprop vendor.oplus.dalvik.vm.heapstartsize $Heapstartsize
    setprop vendor.oplus.dalvik.vm.heapsize $Heapsize
    setprop vendor.oplus.dalvik.vm.heapgrowthlimit $Heapgrowthlimit
    setprop vendor.oplus.dalvik.vm.heaptargetutilization $Heaptargetutilization
    setprop ro.vendor.config.oplus.low_ram false
}

case "$config" in
    "lowram_device_setup")
        lowram_device_setup
    ;;
    "hybridswap")
        hybridswap_setup
        vm_tune
    ;;
    *)
        lowram_device_setup
        hybridswap_setup
        vm_tune
    ;;
esac