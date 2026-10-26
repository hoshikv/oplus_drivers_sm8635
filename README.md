# Oplus drivers sm8635 (6.1 kernel )

Loadable oplus module drivers for sm8635 or devices using 6.1 kernel
including 71 drivers modules in total. Sources are ported from OnePlusOSS
`android_kernel_modules_and_devicetree_oneplus_sm8635`
(`oneplus/sm8635_b_16.0.0_nord_5`) and built against the 6.1 GKI KMI.

The repository is organised by function.

## Layout

```
oplus_drivers_sm8635/
├── build.sh
├── dist/                       # generated .ko output
├── frameboost/
│   ├── afs_config/
│   ├── cpufreq_bouncing/
│   ├── cpufreq_effiency/
│   ├── cpufreq_health/
│   ├── eas_opt/
│   ├── frame_boost/
│   ├── game_opt/
│   ├── hans/
│   ├── levelprotect/
│   ├── midas/
│   ├── oplus_game/
│   ├── oplus_omrg/
│   ├── qos_sched/
│   ├── sched_assist/
│   ├── sched_info/
│   ├── sched_tune/
│   ├── task_cpustats/
│   ├── task_load/
│   ├── task_overload/
│   ├── task_sched/
│   ├── uad/
│   └── waker_identify/
├── hybridswap/
│   ├── hybridswap_zram/
│   ├── odm/
│   ├── zram_opt/
│   └── zstd_o/
├── mm/
│   ├── async_reclaim_opt/
│   ├── dump_tasks_mem/
│   ├── dynamic_readahead/
│   ├── exit_mm_optimize/
│   ├── gloom/
│   ├── kswapd_opt/
│   ├── mm_osvelte/
│   ├── proactive_compact/
│   ├── process_reclaim/
│   ├── uxmem_opt/
│   └── zsmalloc_opt/
├── net/
│   ├── net_data_module/
│   ├── net_linkpower_module/
│   ├── net_oplus_apps_monitor/
│   ├── net_oplus_dns_hook/
│   ├── net_oplus_game_first/
│   ├── net_oplus_network_tuning/
│   ├── net_oplus_qr_scan/
│   ├── net_oplus_score/
│   ├── net_oplus_socket_stats_report/
│   ├── net_oplus_stats_calc/
│   ├── network/
│   └── vnet/
├── power/
│   ├── power_freeze_process/
│   ├── power_procs_load/
│   ├── power_rpmh/
│   ├── power_standby_netlink/
│   └── power_subsys_sleep_monitor/
├── boot/
│   ├── boot_bootloader_log/
│   ├── boot_bootmode/
│   ├── boot_cmdline_parser/
│   ├── boot_htb/
│   ├── boot_oplus_custom/
│   ├── boot_oplus_phoenix/
│   ├── boot_qcom_watchdog/
│   ├── bootprof/
│   ├── oplus_projectinfo/
│   └── shutdown_reason/
├── debug/
│   ├── dfr_fault_inject/
│   ├── memleak_detect/
│   ├── sigkill_diagnosis/
│   └── stability_helper/
├── ipc/
│   └── ipc_vipthread/
├── misc/
│   ├── devinfo/
│   └── healthinfo/
├── storage/
│   ├── io_metrics/
│   └── storage/
├── include/
│   └── soc/
│       └── oplus/
│           ├── boot/
│           │   ├── boot_mode.h
│           │   ├── oplus_project.h
│           │   └── oplus_project_data_ocdt.h
│           └── system/
│               ├── oplus_project.h
│               └── oplus_project_data_ocdt.h
└── tools/
    └── rust-perf/
```

## Build

Requirements:

- a 6.1 kernel tree with a **prepared build directory** (`OUT`), including
  `Module.symvers` and `walt-extra.symvers` (build `sched_walt` first);
- Android NDK clang (default: `android-ndk-r28`).

```sh
./build.sh
```

Useful overrides:

```sh
KERNEL_DIR=/path/to/kernel OUT=/path/to/build/out ./build.sh
STRICT=1 ./build.sh          # abort on first module failure
CLANG_PREBUILT=/path/to/llvm ./build.sh
```

The script:

1. copies every module into `$OUT/oplus-stage` (the repo tree is never
   modified by a build);
2. creates the `kernel/oplus_cpu` and `kernel/mm/oplus_mm` include symlinks
   used by OPLUS' relative `#include <../kernel/...>` paths;
3. injects the per-module `CONFIG_*` defines into the **staged copies**;
4. builds in dependency order;
5. strips and collects all `.ko` files into `./dist`.

## Module mapping

| Category | Modules | Role / upstream area |
|---|---|---|
| `frameboost/` | sched stack, cpufreq, UAG/UAD, HANS, AFS, game and task boosting | `vendor/oplus/kernel/cpu/*` |
| `hybridswap/` | zram, hybridswap core/swapd, zstd/lz4k compressors, zram tuning, ODM scripts | `vendor/oplus/kernel/mm/{hybridswap_zram,zstd,zram_opt}/*` |
| `mm/` | osvelte, exit-mm, readahead, uxmem, kswapd, proactive compaction, async reclaim, zsmalloc, process reclaim, gloom | `vendor/oplus/kernel/mm/*` |
| `net/` | data module, linkpower, app monitor, DNS hook, game-first, network tuning, QR scan, score, socket stats, vnet | `vendor/oplus/kernel/network/*` |
| `power/` | process freeze, proc load, RPMh decoupling, standby netlink, subsystem sleep monitor | `vendor/oplus/kernel/power/*` |
| `boot/` | boot mode, bootloader log, cmdline parser, HTB/tango32, custom, phoenix, watchdog, bootprof, project info, shutdown reason | `vendor/oplus/kernel/boot/*`, `vendor/oplus/kernel/system/*` |
| `debug/` | fault injection (DFR), memleak detection, SIGKILL diagnosis, stability/binder watcher | `vendor/oplus/kernel/{dfr,debug,stability}/*` |
| `ipc/` | binder VIP thread policy and hash/sysfs interface | `vendor/oplus/kernel/ipc/*` |
| `misc/` | device info and healthinfo (CPU/memory/IO health reporting) | `vendor/oplus/kernel/{devinfo,healthinfo}/*` |
| `storage/` | IO metrics (block/F2FS) and UFS/storage debug helpers | `vendor/oplus/kernel/storage/*` |
| `tools/` | `rust-perf` userspace helper (not a kernel module) | local tooling |

## Installation

The modules can be built into the kernel at boot or loaded from `vendor_dlkm`.

### Built into the kernel

Integrate the module sources with the kernel build, enable the matching
`CONFIG_*` options as built-in (`=y`), then rebuild and flash the boot image.

### Load from vendor_dlkm

```sh
adb push dist/*.ko /data/local/tmp/
adb shell su -c 'cp /data/local/tmp/*.ko /vendor_dlkm/lib/modules/$(uname -r)/'
```

Add the module names to `/vendor_dlkm/lib/modules/$(uname -r)/modules.load` in
dependency order, then reboot. If `vendor_dlkm` is mounted read-only, remount
it or flash the updated image.

## License

This project is licensed under the [GNU General Public License v2.0](LICENSE).
