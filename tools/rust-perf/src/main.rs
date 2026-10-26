use std::fs;
use std::process::Command;

fn log(msg: &str) {
    eprintln!("[oplus_perf] {}", msg);
}

fn write_file(path: &str, content: &str) -> bool {
    match fs::write(path, content) {
        Ok(_) => true,
        Err(e) => {
            log(&format!("Failed to write {}: {}", path, e));
            false
        }
    }
}

fn read_file(path: &str) -> String {
    fs::read_to_string(path).unwrap_or_default()
}

fn run_cmd(cmd: &str, args: &[&str]) -> i32 {
    match Command::new(cmd).args(args).status() {
        Ok(status) => status.code().unwrap_or(-1),
        Err(_) => -1,
    }
}

fn run_cmd_output(cmd: &str, args: &[&str]) -> String {
    match Command::new(cmd).args(args).output() {
        Ok(output) => String::from_utf8_lossy(&output.stdout).trim().to_string(),
        Err(_) => String::new(),
    }
}

fn get_memtotal() -> usize {
    let content = read_file("/proc/meminfo");
    for line in content.lines() {
        if line.starts_with("MemTotal:") {
            return line[9..].trim().split_whitespace()
                .next()
                .and_then(|v| v.parse().ok())
                .unwrap_or(0);
        }
    }
    0
}

fn get_disksize() -> usize {
    read_file("/sys/block/zram0/disksize").trim().parse().unwrap_or(0)
}

fn file_exists(path: &str) -> bool {
    std::path::Path::new(path).exists()
}

fn hybridswap_setup() {
    log("hybridswap: owned by oplus performance HAL, skipped here");
}

fn vm_tune() {
    let memtotal = get_memtotal();
    log("Tuning VM parameters...");

    // Per-memcg swappiness (thermal daemon doesn't reset this)
    let memcg_root = if file_exists("/sys/fs/cgroup/memory.swapd_memcgs_param") {
        "/sys/fs/cgroup"
    } else {
        "/dev/memcg"
    };
    log("Per-memcg swappiness: owned by oplus performance HAL");

    write_file("/proc/sys/vm/vfs_cache_pressure", "100");
    write_file("/proc/sys/vm/watermark_scale_factor", "10");
    write_file("/proc/sys/vm/dirty_ratio", "5");
    write_file("/proc/sys/vm/dirty_background_ratio", "1");
    write_file("/proc/sys/vm/dirty_expire_centisecs", "100");
    write_file("/proc/sys/vm/dirty_writeback_centisecs", "100");
    write_file("/proc/sys/vm/compaction_proactiveness", "0");
    write_file("/proc/sys/vm/page-cluster", "0");

    // Reclaim kernel slab (dentry, inode, radix_tree caches)
    write_file("/proc/sys/vm/drop_caches", "3");
    log("Dropped slab caches");

    // Reduce max map count per process (fewer vm_area_struct)
    write_file("/proc/sys/vm/max_map_count", "65530");

    // Reduce min free kbytes — let kernel reclaim earlier
    write_file("/proc/sys/vm/min_free_kbytes", "32768");

    if memtotal <= 8388608 {
        log("Low RAM: enabling aggressive force shrink");
        write_file("/dev/memcg/memory.force_shrink_anon", "1");
        write_file("/dev/memcg/memory.force_shrink_file", "1");
        write_file("/proc/sys/vm/drop_caches", "3");
    }
}

fn lowram_device_setup() {
    let memtotal = get_memtotal();
    let (heapminfree, heapmaxfree, heapstartsize, heapsize, heapgrowthlimit, heaptargetutilization) =
        if memtotal < 9437184 {
            ("2m", "16m", "16m", "512m", "384m", "0.75")
        } else {
            ("4m", "32m", "16m", "512m", "256m", "0.5")
        };

    run_cmd("setprop", &["vendor.oplus.dalvik.vm.heapminfree", heapminfree]);
    run_cmd("setprop", &["vendor.oplus.dalvik.vm.heapmaxfree", heapmaxfree]);
    run_cmd("setprop", &["vendor.oplus.dalvik.vm.heapstartsize", heapstartsize]);
    run_cmd("setprop", &["vendor.oplus.dalvik.vm.heapsize", heapsize]);
    run_cmd("setprop", &["vendor.oplus.dalvik.vm.heapgrowthlimit", heapgrowthlimit]);
    run_cmd("setprop", &["vendor.oplus.dalvik.vm.heaptargetutilization", heaptargetutilization]);
    run_cmd("setprop", &["ro.vendor.config.oplus.low_ram", "false"]);
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let config = if args.len() > 1 { args[1].as_str() } else { "" };

    match config {
        "lowram_device_setup" => lowram_device_setup(),
        "hybridswap" => {
            hybridswap_setup();
            vm_tune();
        }
        _ => {
            lowram_device_setup();
            hybridswap_setup();
            vm_tune();
        }
    }
}
