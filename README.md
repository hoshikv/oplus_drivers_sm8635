# OPlus drivers for peridot (SM8635)

Out-of-tree OPlus/ColorOS kernel modules for the Xiaomi Redmi Turbo 3 / Poco F6
(`peridot`, SM8635, kernel 6.1). Sources are ported from OnePlusOSS
`android_kernel_modules_and_devicetree_oneplus_sm8635`
(`oneplus/sm8635_b_16.0.0_nord_5`) and built against the peridot GKI KMI.

The repo is organised **by function** instead of one flat folder per upstream
sub-repo.

## Layout

```
frameboost/     CPU/scheduler/game modules (oplus_cpu)
  sched_assist/ sched_tune/ sched_info/ eas_opt/ frame_boost/ qos_sched/
  uad/ hans/ afs_config/ cpufreq_bouncing/ cpufreq_effiency/ cpufreq_health/
  oplus_game/ oplus_omrg/ waker_identify/ task_cpustats/ task_load/
  task_sched/ task_overload/ game_opt/ levelprotect/ midas/
hybridswap/     zram + hybridswap stack (oplus_mm)
  hybridswap_zram/ zstd_o/ zram_opt/ odm/
mm/             memory-management tweaks (oplus_mm)
  mm_osvelte/ exit_mm_optimize/ dynamic_readahead/ uxmem_opt/ kswapd_opt/
  proactive_compact/ dump_tasks_mem/ async_reclaim_opt/ zsmalloc_opt/
  process_reclaim/ gloom/
net/            networking modules
  net_data_module/ net_linkpower_module/ net_oplus_*/ network/ vnet/
power/          power/standby modules
  power_freeze_process/ power_procs_load/ power_rpmh/
  power_standby_netlink/ power_subsys_sleep_monitor/
boot/           boot/project/shutdown modules
  boot_bootloader_log/ boot_bootmode/ boot_cmdline_parser/ boot_htb/
  boot_oplus_custom/ boot_oplus_phoenix/ boot_qcom_watchdog/ bootprof/
  oplus_projectinfo/ shutdown_reason/
debug/          stability/storage diagnostics
  dfr_fault_inject/ memleak_detect/ sigkill_diagnosis/ stability_helper/
ipc/            binder VIP thread
  ipc_vipthread/
misc/           device/health info
  devinfo/ healthinfo/
storage/        io metrics / storage helpers
  io_metrics/ storage/
include/        shared headers
  soc/oplus/boot/ soc/oplus/system/
tools/          userspace helpers
  rust-perf/
```

## Build

Requirements:

- peridot kernel tree with a **prepared build directory** (`OUT`), including
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

| Category | Upstream path |
|---|---|
| `frameboost/` | `vendor/oplus/kernel/cpu/{sched,uad,hans,...}` |
| `hybridswap/`, `mm/` | `vendor/oplus/kernel/mm/*` |
| `net/` | `vendor/oplus/kernel/network/*` |
| `power/` | `vendor/oplus/kernel/power/*` |
| `boot/` | `vendor/oplus/kernel/boot/*`, `vendor/oplus/kernel/system/*` |
| `debug/`, `ipc/`, `misc/`, `storage/` | remaining vendor modules |

## License

GPL-2.0. Original sources (c) OPPO/OnePlus; peridot port changes keep the
upstream license. See `LICENSE`.
