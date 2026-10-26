#!/system/bin/sh

# Minimal hybridswap init for Redmi Turbo 3 (PKG110/peridot)
# Place at: /odm/bin/init_hybridswap.sh
# Requires: init rc to call this on boot_completed

nandswap_tool=/product/bin/nandswap_tool
swapfile_path=/data/nandswap/swapfile
swap_size_mb=3072
loop_device=""

log() {
    echo "hybridswap_init: $1"
    log -t "hybridswap_init" "$1"
}

setup_swapfile() {
    if [ ! -f "$swapfile_path" ]; then
        mkdir -p /data/nandswap
        log "Creating ${swap_size_mb}MB swapfile..."
        dd if=/dev/zero of=$swapfile_path bs=1M count=$swap_size_mb 2>/dev/null
        $nandswap_tool -s1 $swapfile_path
        local ret=$?
        if [ $ret -ne 0 ]; then
            log "Failed to pin swapfile: $ret"
            return 1
        fi
        log "Swapfile created and pinned"
    fi
    return 0
}

setup_loop() {
    loop_device=$(losetup -f -s $swapfile_path 2>&1)
    local ret=$?
    if [ $ret -ne 0 ]; then
        log "Failed to create loop device: $loop_device"
        return 1
    fi
    log "Loop device: $loop_device"
    
    $nandswap_tool -l $loop_device
    ret=$?
    if [ $ret -ne 0 ]; then
        log "Failed to set DIO: $ret"
        return 1
    fi
    log "DIO enabled"
    return 0
}

setup_hybridswap() {
    # Set memcg parameters
    local memcg_root="/dev/memcg"
    if [ -e "/sys/fs/cgroup/memory.swapd_memcgs_param" ]; then
        memcg_root="/sys/fs/cgroup"
    fi
    
    echo "3 0 99 0 0 0 100 399 60 0 0 400 499 50 0 0 " > $memcg_root/memory.swapd_memcgs_param
    echo 400 > $memcg_root/memory.app_score
    echo root > $memcg_root/memory.name
    echo "2200 1800 2200 1536" > $memcg_root/memory.avail_buffers
    echo 4972 > $memcg_root/memory.zram_critical_threshold  # 5100 - 128
    echo 50 > $memcg_root/memory.swapd_max_reclaim_size
    echo "1000 50" > $memcg_root/memory.swapd_shrink_parameter
    echo 5000 > $memcg_root/memory.max_skip_interval
    echo 50 > $memcg_root/memory.reclaim_exceed_sleep_ms
    echo 60 > $memcg_root/memory.cpuload_threshold
    echo 30 > $memcg_root/memory.max_reclaimin_size_mb
    echo 80 > $memcg_root/memory.zram_wm_ratio
    echo 512 > $memcg_root/memory.empty_round_skip_interval
    echo 20 > $memcg_root/memory.empty_round_check_threshold
    echo 1 > /sys/block/zram0/hybridswap_loglevel
    
    # Set loop device and enable
    echo -n "$loop_device" > /sys/block/zram0/hybridswap_loop_device
    echo 1 > /sys/block/zram0/hybridswap_enable
    
    log "Hybridswap enabled"
    return 0
}

main() {
    log "Starting initialization..."
    
    setup_swapfile || exit 1
    setup_loop || exit 1
    setup_hybridswap || exit 1
    
    log "Initialization complete"
    exit 0
}

main