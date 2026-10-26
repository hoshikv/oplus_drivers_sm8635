#!/usr/bin/env bash
#
# build.sh — build the full OPlus driver set for peridot (sm8635, k6.1).
#
# The repo is organised by function:
#
#   frameboost/   cpu/sched/game DLKMs
#   hybridswap/   zram + hybridswap stack
#   mm/           memory-management tweaks
#   net/          network modules
#   power/        power/standby modules
#   boot/         boot/project/shutdown modules
#   debug/        stability/dfr/memleak/sigkill
#   ipc/          binder VIP thread
#   misc/         devinfo/healthinfo
#   storage/      io metrics / storage
#   include/      shared soc/oplus headers
#   tools/        userspace helpers
#
# It copies every module into an out-of-tree staging tree, injects the feature
# defines each module needs, builds in dependency order, and collects all .ko
# files into ./dist. The repo sources themselves are never modified.
#
# Usage:
#   ./build.sh                # build everything into ./dist
#   STRICT=1 ./build.sh       # treat any module failure as fatal
#   KERNEL_DIR=... OUT=... ./build.sh
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FB_DIR="$ROOT/frameboost"
HS_DIR="$ROOT/hybridswap"
MM_DIR="$ROOT/mm"
NET_DIR="$ROOT/net"
PWR_DIR="$ROOT/power"
BOOT_DIR="$ROOT/boot"
DBG_DIR="$ROOT/debug"
IPC_DIR="$ROOT/ipc"
MISC_DIR="$ROOT/misc"
STORAGE_DIR="$ROOT/storage"
INCLUDE_DIR="$ROOT/include"

KERNEL_DIR="${KERNEL_DIR:-/home/hoshikava/Downloads/Kv/peridot-build/kernel}"
OUT="${OUT:-/home/hoshikava/Downloads/Kv/peridot-build/build/out}"
ARCH=arm64
JOBS="${JOBS:-$(nproc --ignore 2)}"
STRICT="${STRICT:-0}"

CLANG_PREBUILT="${CLANG_PREBUILT:-/home/hoshikava/android-ndk-r28/toolchains/llvm/prebuilt/linux-x86_64}"

DIST="$ROOT/dist"
LOGDIR="$OUT/oplus_build_logs"
mkdir -p "$OUT" "$DIST" "$LOGDIR" "$OUT/msym"

# ---------------------------------------------------------------------------
# Toolchain / env (clang NDK r28)
# ---------------------------------------------------------------------------
if [[ -d "$CLANG_PREBUILT/bin" ]]; then
  export PATH="$CLANG_PREBUILT/bin:$PATH"
fi
export CC=clang
export LLVM=1 LLVM_IAS=1 SUBARCH=arm64 ARCH
export LD=ld.lld AR=llvm-ar NM=llvm-nm STRIP=llvm-strip
export OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump READELF=llvm-readelf

[[ -f "$KERNEL_DIR/Makefile" ]] || { echo "kernel tree missing at $KERNEL_DIR"; exit 1; }
[[ -f "$OUT/walt-extra.symvers" ]] || { echo "walt-extra.symvers missing at $OUT/walt-extra.symvers (build sched_walt first)"; exit 1; }

# ---------------------------------------------------------------------------
# Staging
# ---------------------------------------------------------------------------
STAGE="$OUT/oplus-stage"
FB_STAGE="$STAGE/fb/kernel"
HS_STAGE="$STAGE/hs/kernel"
SRC_STAGE="$STAGE/src"
INCBASE="$STAGE/incbase"

# in-tree-ish roots used by the OPLUS relative includes
FB="$FB_STAGE/oplus_cpu"          # -> <../kernel/oplus_cpu/...>
HS_M="$HS_STAGE/oplus_mm"         # -> <../kernel/oplus_mm/...> / -I$(srctree)/mm/oplus_mm
INC="$INCBASE"                    # -> <soc/oplus/...>, <linux/...>, <trace/events/...>

rm -rf "$STAGE"
mkdir -p \
  "$FB/sched" \
  "$HS_M" \
  "$HS_STAGE/oplus_cpu/sched/sched_assist" \
  "$SRC_STAGE" \
  "$INC/kernel" "$INC/linux" "$INC/trace/events"

# shared OPLUS headers: include/soc/oplus/{boot,system}/...
ln -sfn "$INCLUDE_DIR/soc" "$INC/soc"

copy_module() { # $1=src dir  $2=dst dir
  local src="$1" dst="$2"
  rm -rf "$dst"
  mkdir -p "$(dirname "$dst")"
  cp -a "$src" "$dst"
  find "$dst" -type f \
    \( -name '*.o' -o -name '*.ko' -o -name '*.mod' -o -name '*.mod.c' \
       -o -name '*.mod.o' -o -name '.*.cmd' -o -name '*.o.d' \
       -o -name 'Module.symvers' -o -name 'modules.order' \
       -o -name '.modules.order.cmd' -o -name '.Module.symvers.cmd' \) \
    -delete
  find "$dst" -type d -name '.tmp_versions' -prune -exec rm -rf {} +
}

stage_module() { # $1=category  $2=module ; echoes staged path
  local dst="$SRC_STAGE/$1/$2"
  copy_module "$ROOT/$1/$2" "$dst"
  printf '%s' "$dst"
}

# ---------------------------------------------------------------------------
# Headers / symlink farm
# ---------------------------------------------------------------------------
# category-A cpu headers using <linux/...> / <trace/events/...> style includes
[[ -f "$FB_DIR/cpufreq_bouncing/cpufreq_bouncing.h" ]] && \
  cp -f "$FB_DIR/cpufreq_bouncing/cpufreq_bouncing.h" "$INC/linux/"
[[ -f "$FB_DIR/cpufreq_effiency/cpufreq_effiency.h" ]] && \
  cp -f "$FB_DIR/cpufreq_effiency/cpufreq_effiency.h" "$INC/linux/"
[[ -f "$FB_DIR/oplus_omrg/oplus_omrg_trace.h" ]] && \
  cp -f "$FB_DIR/oplus_omrg/oplus_omrg_trace.h" "$INC/trace/events/"
[[ -f "$FB_DIR/oplus_omrg/oplus_omrg.h" ]] && \
  cp -f "$FB_DIR/oplus_omrg/oplus_omrg.h" "$INC/linux/"
[[ -f "$FB_DIR/cpufreq_health/cpufreq_health.h" ]] && \
  cp -f "$FB_DIR/cpufreq_health/cpufreq_health.h" "$INC/linux/cpufreq_health.h"

# frameboost sched stack under oplus_cpu/sched
for d in sched_tune sched_assist eas_opt frame_boost qos_sched sched_info; do
  copy_module "$FB_DIR/$d" "$FB/sched/$d"
done
# task_load / task_sched live in frameboost/ but need the sched tree layout
for d in task_load task_sched; do
  copy_module "$FB_DIR/$d" "$FB/sched/$d"
done
# other cpu modules under oplus_cpu
for d in uad hans afs_config cpufreq_bouncing cpufreq_effiency oplus_game \
         oplus_omrg waker_identify task_cpustats cpufreq_health; do
  copy_module "$FB_DIR/$d" "$FB/$d"
done

# hybridswap + mm under oplus_mm (relative includes expect them side by side)
for d in hybridswap_zram zstd_o zram_opt; do
  copy_module "$HS_DIR/$d" "$HS_M/$d"
done
for d in mm_osvelte exit_mm_optimize dynamic_readahead uxmem_opt kswapd_opt \
         proactive_compact dump_tasks_mem async_reclaim_opt zsmalloc_opt \
         process_reclaim gloom; do
  copy_module "$MM_DIR/$d" "$HS_M/$d"
done
# sched_assist shared header for hybridswap
ln -sfn "$FB/sched/sched_assist/sa_common.h" "$HS_STAGE/oplus_cpu/sched/sched_assist/sa_common.h"

# include base: resolves `#include <../kernel/oplus_cpu/...>` and
# `<linux/cpufreq_health.h>` for the out-of-tree modules.
ln -sfn "$FB" "$INC/kernel/oplus_cpu"

# kernel-tree include roots used by the OnePlus sources
if [[ -L "$KERNEL_DIR/oplus_cpu" || ! -e "$KERNEL_DIR/oplus_cpu" ]]; then
  ln -sfn "$FB" "$KERNEL_DIR/oplus_cpu"
else
  echo "[!] $KERNEL_DIR/oplus_cpu exists and is not a symlink; leaving it alone"
fi
mkdir -p "$KERNEL_DIR/mm"
if [[ -L "$KERNEL_DIR/mm/oplus_mm" || ! -e "$KERNEL_DIR/mm/oplus_mm" ]]; then
  ln -sfn "$HS_M" "$KERNEL_DIR/mm/oplus_mm"
fi
if [[ -L "$KERNEL_DIR/mm/oplus_mm_new" || ! -e "$KERNEL_DIR/mm/oplus_mm_new" ]]; then
  ln -sfn "$HS_M" "$KERNEL_DIR/mm/oplus_mm_new"
fi
# task_load/task_sched use -I$(srctree)/.. and <../fs/proc/internal.h>
KPARENT="$(dirname "$KERNEL_DIR")"
if [[ ! -e "$KPARENT/fs" ]]; then
  ln -sfn "$KERNEL_DIR/fs" "$KPARENT/fs"
fi

# Common -I list baked into KCFLAGS for the "new" modules
NEW_KCFLAGS=(
  "-I$INC"
  "-I$INC/kernel"
  "-I$FB/sched/frame_boost"
  "-I$FB/sched/sched_assist"
  "-I$FB/sched/sched_info"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log() { echo "[*] $*"; }

# inject ccflags defines into a staged module's Kbuild/Makefile (idempotent)
inject_defines() { # $1=abs dir  rest=CONFIG_X
  local f="$1/Kbuild"; [[ -f "$f" ]] || f="$1/Makefile"
  [[ -s "$f" ]] && [[ -n "$(tail -c1 "$f")" ]] && echo >> "$f"
  grep -q 'ccflags-y += -I$(src)' "$f" || echo 'ccflags-y += -I$(src)' >> "$f"
  local d
  shift
  for d in "$@"; do
    grep -qF -- "ccflags-y += -D$d=1" "$f" || echo "ccflags-y += -D$d=1" >> "$f"
  done
}

# shared sched feature set (must be identical across all frameboost modules so
# shared OPLUS headers build with the same struct/layout guards)
FB_SCHED_FEAT="CONFIG_OPLUS_FEATURE_SCHED_ASSIST CONFIG_OPLUS_FEATURE_SCHED_DDL CONFIG_OPLUS_SCHED_GROUP_OPT CONFIG_OPLUS_CPU_AUDIO_PERF CONFIG_OPLUS_FEATURE_LOADBALANCE CONFIG_OPLUS_FEATURE_PIPELINE CONFIG_BLOCKIO_UX_OPT CONFIG_OPLUS_FEATURE_FRAME_BOOST"

FAILED=""

# mbuild <label> <M-abs-dir> <extra-symvers> <kcflags-var-or-empty> <make-configs...>
mbuild() {
  local label="$1" M="$2" EXTRA="$3" KCF="$4"; shift 4
  local logf="$LOGDIR/$label.log"
  local kcflags=""
  [[ -n "$KCF" ]] && kcflags="$KCF"
  make -C "$KERNEL_DIR" O="$OUT" -j"$JOBS" ARCH="$ARCH" \
    KERNEL_SRC="$KERNEL_DIR" KERNEL_ROOT="$KERNEL_DIR" \
    KBUILD_EXTRA_SYMBOLS="$OUT/walt-extra.symvers $EXTRA" \
    KBUILD_MODPOST_WARN=1 \
    CONFIG_ARCH_PINEAPPLE=y \
    KCFLAGS="$kcflags" \
    M="$M" "$@" modules >"$logf" 2>&1 || {
      echo "  ! $label FAILED (see $logf)"
      grep -nE "error:|fatal|undefined|undeclared|No such|No rule" "$logf" | head -20 || true
      if [[ "$STRICT" == "1" ]]; then echo "STRICT=1 -> abort"; exit 1; fi
      FAILED="$FAILED $label"
      return 0
    }
  echo "  ok $label"
}

# mbuild_cat <label> <category> <module> <extra-symvers> <kcflags> <make-configs...>
mbuild_cat() {
  local label="$1" cat="$2" mod="$3" EXTRA="$4" KCF="$5"; shift 5
  local M="$SRC_STAGE/$cat/$mod"
  copy_module "$ROOT/$cat/$mod" "$M"
  mbuild "$label" "$M" "$EXTRA" "$KCF" "$@"
}

cache_symvers() { # $1=abs module dir  $2=symvers name
  local p="$1/Module.symvers"
  if [[ -f "$p" ]]; then cp -f "$p" "$OUT/msym/$2.symvers"; else : > "$OUT/msym/$2.symvers"; fi
}

collect_ko() { # $1=src tree  $2=out dir
  mkdir -p "$2"
  while IFS= read -r ko; do [[ -f "$ko" ]] && cp -f "$ko" "$2/"; done \
    < <(find "$1" -name '*.ko' 2>/dev/null)
}

# ===========================================================================
# SECTION A — FRAMEBOOST sched stack (device-loaded + new schedinfo/och)
# ===========================================================================
log "frameboost sched stack"

inject_defines "$FB/sched/sched_tune"   CONFIG_OPLUS_SYSTEM_KERNEL_QCOM CONFIG_OPLUS_SCHED_TUNE $FB_SCHED_FEAT
inject_defines "$FB/sched/eas_opt"      CONFIG_OPLUS_SYSTEM_KERNEL_QCOM CONFIG_OPLUS_FEATURE_EAS_OPT CONFIG_OPLUS_FEATURE_VT_CAP CONFIG_OPLUS_CPUFREQ_IOWAIT_PROTECT $FB_SCHED_FEAT
inject_defines "$FB/sched/sched_assist" CONFIG_OPLUS_SYSTEM_KERNEL_QCOM CONFIG_OPLUS_FEATURE_SCHED_ASSIST $FB_SCHED_FEAT
inject_defines "$FB/sched/frame_boost"  CONFIG_OPLUS_SYSTEM_KERNEL_QCOM CONFIG_OPLUS_FEATURE_FRAME_BOOST $FB_SCHED_FEAT
inject_defines "$FB/sched/qos_sched"    CONFIG_OPLUS_SYSTEM_KERNEL_QCOM CONFIG_OPLUS_FEATURE_QOS_SCHED $FB_SCHED_FEAT
inject_defines "$FB/uad"                CONFIG_OPLUS_SYSTEM_KERNEL_QCOM CONFIG_OPLUS_CPU_FREQ_GOV_UAG CONFIG_UA_KERNEL_CPU_IOCTL CONFIG_OPLUS_FEATURE_FRAME_BOOST CONFIG_UAG_NONLINEAR_FREQ_CTL CONFIG_OPLUS_UAG_USE_TL CONFIG_OPLUS_MULTI_LV_TL CONFIG_OPLUS_FEATURE_VT_CAP $FB_SCHED_FEAT
inject_defines "$FB/hans"               CONFIG_OPLUS_SYSTEM_KERNEL_QCOM CONFIG_OPLUS_FEATURE_HANS $FB_SCHED_FEAT

mbuild sched_tune "$FB/sched/sched_tune" "" "" \
  CONFIG_OPLUS_SCHED_TUNE=m CONFIG_OPLUS_SYSTEM_KERNEL_QCOM=y
cache_symvers "$FB/sched/sched_tune" sched_tune

mbuild sched_assist "$FB/sched/sched_assist" "$OUT/msym/sched_tune.symvers" "" \
  CONFIG_OPLUS_FEATURE_SCHED_ASSIST=m CONFIG_OPLUS_SYSTEM_KERNEL_QCOM=y \
  CONFIG_OPLUS_FEATURE_SCHED_DDL=y CONFIG_OPLUS_SCHED_GROUP_OPT=y \
  CONFIG_OPLUS_CPU_AUDIO_PERF=y CONFIG_OPLUS_FEATURE_LOADBALANCE=y \
  CONFIG_OPLUS_FEATURE_PIPELINE=y CONFIG_BLOCKIO_UX_OPT=y
cache_symvers "$FB/sched/sched_assist" sched_assist

mbuild eas_opt "$FB/sched/eas_opt" "$OUT/msym/sched_assist.symvers" "" \
  CONFIG_OPLUS_FEATURE_EAS_OPT=m CONFIG_OPLUS_SYSTEM_KERNEL_QCOM=y \
  CONFIG_OPLUS_FEATURE_VT_CAP=y CONFIG_OPLUS_CPUFREQ_IOWAIT_PROTECT=y
cache_symvers "$FB/sched/eas_opt" eas_opt

mbuild frame_boost "$FB/sched/frame_boost" "$OUT/msym/sched_assist.symvers $OUT/msym/eas_opt.symvers" "" \
  CONFIG_OPLUS_FEATURE_FRAME_BOOST=m CONFIG_OPLUS_SYSTEM_KERNEL_QCOM=y
cache_symvers "$FB/sched/frame_boost" frame_boost

mbuild qos_sched "$FB/sched/qos_sched" "$OUT/msym/sched_assist.symvers $OUT/msym/frame_boost.symvers $OUT/msym/eas_opt.symvers" "" \
  CONFIG_OPLUS_FEATURE_QOS_SCHED=m CONFIG_OPLUS_SYSTEM_KERNEL_QCOM=y
cache_symvers "$FB/sched/qos_sched" qos_sched

mbuild uad "$FB/uad" "$OUT/msym/sched_assist.symvers $OUT/msym/eas_opt.symvers $OUT/msym/frame_boost.symvers" "" \
  CONFIG_OPLUS_CPU_FREQ_GOV_UAG=m CONFIG_UA_KERNEL_CPU_IOCTL=m CONFIG_OPLUS_SYSTEM_KERNEL_QCOM=y \
  CONFIG_UAG_NONLINEAR_FREQ_CTL=y CONFIG_OPLUS_UAG_USE_TL=y CONFIG_OPLUS_MULTI_LV_TL=y \
  CONFIG_OPLUS_FEATURE_VT_CAP=y CONFIG_OPLUS_FEATURE_FRAME_BOOST=y
cache_symvers "$FB/uad" uad

mbuild hans "$FB/hans" "" "" CONFIG_OPLUS_FEATURE_HANS=m CONFIG_OPLUS_SYSTEM_KERNEL_QCOM=y
mbuild afs_config "$FB/afs_config" "" "" CONFIG_OPLUS_FEATURE_AFS_CONFIG=m

# NEW: schedinfo (osi_*). Needs the JANKINFO macro as a preprocessor define
# (not just a make var) so its internal IS_ENABLED guards compile.
mbuild schedinfo "$FB/sched/sched_info" "$OUT/msym/sched_assist.symvers" \
  "-DCONFIG_OPLUS_FEATURE_CPU_JANKINFO=1" \
  CONFIG_OPLUS_FEATURE_CPU_JANKINFO=m CONFIG_OPLUS_SYSTEM_KERNEL_QCOM=y
cache_symvers "$FB/sched/sched_info" sched_info

# NEW: cpufreq_health. CONFIG_OPLUS_FEATURE_OCH macro is injected in its Makefile.
# <linux/cpufreq_health.h> lives in the incbase staging dir.
mbuild cpufreq_health "$FB/cpufreq_health" "$OUT/msym/sched_info.symvers" "${NEW_KCFLAGS[*]}" \
  CONFIG_OPLUS_FEATURE_OCH=m CONFIG_OPLUS_SYSTEM_KERNEL_QCOM=y

# ===========================================================================
# SECTION B — HYBRIDSWAP + MM (device-loaded zram + new mm tweaks)
# ===========================================================================
log "hybridswap / mm"

inject_defines "$HS_M/hybridswap_zram" CONFIG_HYBRIDSWAP CONFIG_HYBRIDSWAP_SWAPD CONFIG_HYBRIDSWAP_CORE

# child crypto modules first
mbuild lz4k "$HS_M/hybridswap_zram/lz4k" "" "" CONFIG_CRYPTO_LZ4K=m
mbuild zstd_crypto "$HS_M/hybridswap_zram/zstd" "" "" CONFIG_CRYPTO_ZSTDN=m
mbuild hybridswap_zram "$HS_M/hybridswap_zram" "" "" \
  CONFIG_HYBRIDSWAP_ZRAM=m CONFIG_HYBRIDSWAP=y CONFIG_HYBRIDSWAP_SWAPD=y CONFIG_HYBRIDSWAP_CORE=y

# NEW: mm_osvelte (provides osvelte_kallsyms_lookup_name for zstd_o)
mbuild mm_osvelte "$HS_M/mm_osvelte" "" "-D__ANDROID_COMMON_KERNEL__" \
  CONFIG_OPLUS_FEATURE_MM_OSVELTE=m
cache_symvers "$HS_M/mm_osvelte" mm_osvelte

# NEW: crypto_zstdn_o (depends on mm_osvelte exports)
mbuild crypto_zstdn_o "$HS_M/zstd_o" "$OUT/msym/mm_osvelte.symvers" "" \
  CONFIG_CRYPTO_ZSTDN=m

# NEW: mm tweaks. They pull frameboost/sched headers, so they need the
# frameboost include dirs + schedinfo/eas exports for is_fg / helpers.
NEW_HS_EXTRA="$OUT/msym/sched_assist.symvers $OUT/msym/sched_info.symvers $OUT/msym/eas_opt.symvers $OUT/msym/mm_osvelte.symvers"
NEW_HS_KC="${NEW_KCFLAGS[*]}"

mbuild exit_mm_optimize    "$HS_M/exit_mm_optimize"    "$NEW_HS_EXTRA" "$NEW_HS_KC" CONFIG_OPLUS_EXIT_MM_OPTIMIZE=m
mbuild dynamic_readahead   "$HS_M/dynamic_readahead"   "$NEW_HS_EXTRA" "$NEW_HS_KC" CONFIG_OPLUS_FEATURE_DYNAMIC_READAHEAD=m
mbuild uxmem_opt           "$HS_M/uxmem_opt"           "$NEW_HS_EXTRA" "$NEW_HS_KC" CONFIG_OPLUS_FEATURE_UXMEM_OPT=m
mbuild kswapd_opt          "$HS_M/kswapd_opt"          "$NEW_HS_EXTRA" "$NEW_HS_KC" CONFIG_OPLUS_FEATURE_KSWAPD_OPT=m
mbuild proactive_compact   "$HS_M/proactive_compact"   "$NEW_HS_EXTRA" "$NEW_HS_KC" CONFIG_OPLUS_FEATURE_PROACTIVE_COMPACT=m
mbuild kshrink_slabd       "$HS_M/async_reclaim_opt/kshrink_slabd" "$NEW_HS_EXTRA" "$NEW_HS_KC" CONFIG_KSHRINK_SLABD=m
mbuild pcppages_opt        "$HS_M/async_reclaim_opt/pcppages_opt"  "$NEW_HS_EXTRA" "$NEW_HS_KC" CONFIG_PCPPAGES_OPT=m
mbuild dump_tasks_mm       "$HS_M/dump_tasks_mem"      "$NEW_HS_EXTRA" "$NEW_HS_KC" CONFIG_DUMP_TASKS_MEM=m

# ===========================================================================
# SECTION C — SYSTEM DRIVERS (cpu/game, midas, zram_opt, boot, net, power...)
# ===========================================================================
log "system drivers"

NEW_OP_EXTRA="$OUT/msym/sched_assist.symvers $OUT/msym/frame_boost.symvers $OUT/msym/eas_opt.symvers $OUT/msym/sched_info.symvers"
NEW_OP_KC="${NEW_KCFLAGS[*]}"

# midas (device-loaded) — needs BINDER_STATS_ENABLE so binder_stats_dev compiles
mbuild_cat midas frameboost midas "" "" \
  CONFIG_OPLUS_FEATURE_MIDAS_GKI=m CONFIG_OPLUS_FEATURE_BINDER_STATS_ENABLE=y

# task_load / task_sched staged into frameboost sched tree, built with the
# shared frameboost feature set so shared OPLUS header structs match.
inject_defines "$FB/sched/task_load"  CONFIG_OPLUS_SYSTEM_KERNEL_QCOM CONFIG_OPLUS_FEATURE_TASK_LOAD  CONFIG_OPLUS_FEATURE_SCHED_ASSIST $FB_SCHED_FEAT
inject_defines "$FB/sched/task_sched" CONFIG_OPLUS_SYSTEM_KERNEL_QCOM CONFIG_OPLUS_FEATURE_TASK_SCHED CONFIG_OPLUS_FEATURE_SCHED_ASSIST $FB_SCHED_FEAT

mbuild task_load "$FB/sched/task_load" "$OUT/msym/sched_assist.symvers $OUT/msym/frame_boost.symvers $OUT/msym/eas_opt.symvers" "" \
  CONFIG_OPLUS_FEATURE_TASK_LOAD=m
cache_symvers "$FB/sched/task_load" task_load

mbuild task_sched "$FB/sched/task_sched" "$OUT/msym/sched_assist.symvers $OUT/msym/frame_boost.symvers $OUT/msym/eas_opt.symvers" "" \
  CONFIG_OPLUS_FEATURE_TASK_SCHED=m

# zram_opt (zram tuning)
mbuild zram_opt "$HS_M/zram_opt" "" "" CONFIG_OPLUS_FEATURE_ZRAM_OPT=m

# boot / project / shutdown
mbuild_cat bootprof boot bootprof "" "" CONFIG_OPLUS_FEATURE_BOOTPROF=m
mbuild_cat shutdown_reason boot shutdown_reason "" "" CONFIG_OPLUS_FEATURE_SHUTDOWN_REASON=m

# oplus_projectinfo: pick the qcom variant (Makefile keys off the make var).
M="$(stage_module boot oplus_projectinfo)"
inject_defines "$M"
mbuild oplus_projectinfo "$M" "" "" \
  CONFIG_OPLUS_FEATURE_OPROJECT=m CONFIG_OPLUS_SYSTEM_KERNEL_QCOM=y

mbuild_cat healthinfo misc healthinfo "" "" CONFIG_OPLUS_FEATURE_HEALTHINFO=m
mbuild_cat vnet net vnet "" "" CONFIG_OPLUS_FEATURE_VIRTUAL_NET=m

# NEW: game_opt (task_boost subdir needs -I$(src) to reach parent game_ctrl.h)
M="$(stage_module frameboost game_opt)"
inject_defines "$M"
mbuild game_opt "$M" "$NEW_OP_EXTRA" "$NEW_OP_KC" CONFIG_OPLUS_FEATURE_GAME_OPT=m

# NEW: level_protect + fg_protect (same dir, two objs)
M="$(stage_module frameboost levelprotect)"
mbuild level_protect "$M" "$NEW_OP_EXTRA" "$NEW_OP_KC" \
  CONFIG_OPLUS_LEVEL_PROTECT=m CONFIG_OPLUS_FG_PROTECT=m

# NEW: sigkill_diagnosis
mbuild_cat sigkill_diagnosis debug sigkill_diagnosis "$NEW_OP_EXTRA" "$NEW_OP_KC" \
  CONFIG_OPLUS_FEATURE_SIGKILL_DIAGNOSIS=m

# --- CPU (frameboost) ---
# These modules guard their extern decls vs static-inline stubs with
# IS_ENABLED()/IS_MODULE() on a config we only pass as a make var. The
# preprocessor needs it as a real -D macro too, else the header emits stubs
# that collide with the .c real definitions (redefinition errors).
mbuild cpufreq_bouncing "$FB/cpufreq_bouncing" "$OUT/msym/sched_assist.symvers" \
  "${NEW_KCFLAGS[*]} -DCONFIG_OPLUS_FEATURE_GKI_CPUFREQ_BOUNCING=1" \
  CONFIG_OPLUS_FEATURE_GKI_CPUFREQ_BOUNCING=m CONFIG_OPLUS_SYSTEM_KERNEL_QCOM=y
mbuild cpufreq_effiency "$FB/cpufreq_effiency" "$OUT/msym/sched_assist.symvers" "${NEW_KCFLAGS[*]}" \
  CONFIG_OPLUS_FEATURE_SUGOV_POWER_EFFIENCY=m
mbuild oplus_game "$FB/oplus_game" "$OUT/msym/sched_assist.symvers" "${NEW_KCFLAGS[*]}" \
  CONFIG_OPLUS_FEATURE_CPU_GAME=m
mbuild oplus_omrg "$FB/oplus_omrg" "" "${NEW_KCFLAGS[*]} -DCONFIG_OPLUS_OMRG=1" \
  CONFIG_OPLUS_OMRG=m
mbuild waker_identify "$FB/waker_identify" "" "${NEW_KCFLAGS[*]}" \
  CONFIG_OPLUS_FEATURE_WAKER_IDENTIFY=m
mbuild task_cpustats "$FB/task_cpustats" "" "${NEW_KCFLAGS[*]}" \
  CONFIG_OPLUS_FEATURE_TASK_CPUSTATS=m

# --- POWER ---
mbuild_cat power_freeze_process power power_freeze_process "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_FREEZE_PROCESS_HOOK=m
mbuild_cat power_procs_load power power_procs_load "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_POWER_PROCS_LOAD=m
mbuild_cat power_rpmh power power_rpmh "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_RPMH_DECOUPLING=m
mbuild_cat power_standby_netlink power power_standby_netlink "" "${NEW_OP_KC} -DCONFIG_OPLUS_STANDBY_NETLINK_QCOM=1" \
  CONFIG_OPLUS_FEATURE_POWER_NETLINK=m
M="$(stage_module power power_subsys_sleep_monitor)"
mbuild power_subsys_sleep_monitor "$M" "" "${NEW_OP_KC} -I$M" \
  CONFIG_OPLUS_SUBSYS_SLEEP_MONITOR=m

# --- NETWORK ---
mbuild_cat net_data_module net net_data_module "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_DATA_MODULE=m
mbuild_cat net_linkpower_module net net_linkpower_module "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_QCOM=m
mbuild_cat net_oplus_apps_monitor net net_oplus_apps_monitor "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_APP_MONITOR=m
mbuild_cat net_oplus_dns_hook net net_oplus_dns_hook "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_DNS_HOOK=m
mbuild_cat net_oplus_game_first net net_oplus_game_first "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_GAME_FIRST=m
mbuild_cat net_oplus_network_tuning net net_oplus_network_tuning "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_KERNEL_NETWORK_PARA=m
mbuild_cat net_oplus_qr_scan net net_oplus_qr_scan "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_QR_SCAN=m
mbuild_cat net_oplus_score net net_oplus_score "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_DATA_EVAL=m
mbuild_cat net_oplus_socket_stats_report net net_oplus_socket_stats_report "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_ESTABLISH_REPORT=m
mbuild_cat net_oplus_stats_calc net net_oplus_stats_calc "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_STATS_CALC=m

# --- BOOT ---
mbuild_cat boot_bootloader_log boot boot_bootloader_log "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_BOOTLOADER_LOG=m
mbuild_cat boot_bootmode boot boot_bootmode "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_BOOTMODE=m
mbuild_cat boot_cmdline_parser boot boot_cmdline_parser "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_BOOTARGS=m CONFIG_OPLUS_FEATURE_BUILDVARIANT=y CONFIG_OPLUS_FEATURE_CDT=y \
  CONFIG_OPLUS_FEATURE_OPLUSBOOT=m CONFIG_OPLUS_FEATURE_FTMMODE=m CONFIG_OPLUS_FEATURE_CHARGERPRESENT=m
mbuild_cat boot_htb boot boot_htb "" "${NEW_OP_KC}" \
  CONFIG_TANGO32=m
mbuild_cat boot_oplus_custom boot boot_oplus_custom "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_OPLUS_CUSTOM=m
mbuild_cat boot_oplus_phoenix boot boot_oplus_phoenix "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_PHOENIX=m CONFIG_OPLUS_FEATURE_KMSG_WB=y CONFIG_OPLUS_FEATURE_PHOENIX_REBOOT_SPEED=y
mbuild_cat boot_qcom_watchdog boot boot_qcom_watchdog "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_QCOM_WATCHDOG=m

# --- DEBUG / STABILITY / DFR ---
M="$(stage_module ipc ipc_vipthread)"
inject_defines "$M"
mbuild ipc_vipthread "$M" "" "${NEW_OP_KC} -I$KERNEL_DIR/drivers/android -I$M" \
  CONFIG_ANDROID_BINDER_IPC_VIP_THREAD=m

M="$(stage_module debug stability_helper)"
inject_defines "$M"
mbuild stability_helper "$M" "" "${NEW_OP_KC} -I$KERNEL_DIR -I$KERNEL_DIR/drivers/staging/android" \
  CONFIG_OPLUS_FEATURE_STABILITY_HELPER=m

mbuild_cat dfr_fault_inject debug dfr_fault_inject "" "${NEW_OP_KC}" \
  CONFIG_OPLUS_FEATURE_FAULT_INJECT=m

# ===========================================================================
# Collect
# ===========================================================================
log "collect .ko -> dist"
rm -rf "$DIST"; mkdir -p "$DIST"
collect_ko "$STAGE" "$DIST"
for ko in "$DIST"/*.ko; do [[ -f "$ko" ]] && "$STRIP" --strip-debug "$ko" 2>/dev/null || true; done

# expected set (device-loaded + the 15 new)
EXPECTED="
cpufreq_uag ua_cpu_ioctl oplus_afs_config oplus_bsp_eas_opt oplus_bsp_frame_boost
oplus_hans oplus_bsp_qos_sched oplus_bsp_sched_assist oplus_bsp_schedtune
crypto_zstdn oplus_bsp_hybridswap_zram oplus_bsp_lz4k
oplus_bsp_midas oplus_bsp_task_load oplus_bsp_task_sched oplus_bsp_zram_opt
oplus_bootprof oplus_shutdown_reason oplus_bsp_boot_projectinfo
oplus_bsp_healthinfo oplus_vnet
oplus_bsp_schedinfo oplus_bsp_cpufreq_health
oplus_exit_mm_optimize oplus_bsp_dynamic_readahead oplus_bsp_uxmem_opt
oplus_bsp_kshrink_slabd oplus_bsp_pcppages_opt oplus_bsp_kswapd_opt
oplus_bsp_proactive_compact oplus_bsp_dump_tasks_mm crypto_zstdn_o
oplus_bsp_mm_osvelte oplus_bsp_game_opt oplus_bsp_level_protect
oplus_bsp_fg_protect oplus_bsp_sigkill_diagnosis
cpufreq_bouncing cpufreq_effiency oplus_bsp_cpu_game oplus_bsp_omrg
oplus_bsp_waker_identify oplus_bsp_task_cpustats
oplus_freeze_process oplus_procs_load oplus_rpmh_statics oplus_standby_netlink
oplus_subsys_sleep_monitor
oplus_data_module oplus_app_monitor oplus_dns_hook oplus_game_first
oplus_network_linkpower_module oplus_networks_tuning oplus_qr_scan oplus_score
oplus_stats_calc
bootloader_log boot_mode oplus_bootargs oplus_custom oplus_phoenix
qcom_enhance_watchdog tango32
oplus_stability_helper oplus_vip_binder
"
log "built modules:"
ls -1 "$DIST"/*.ko 2>/dev/null | xargs -n1 basename | sort | sed 's/^/    /'

log "missing (expected but not built):"
missing_any=0
for m in $EXPECTED; do
  [[ -f "$DIST/$m.ko" ]] || { echo "    - $m.ko"; missing_any=1; }
done
[[ "$missing_any" == "0" ]] && echo "    (none)"

echo
if [[ -n "$FAILED" ]]; then
  echo "[!] failures:$FAILED"
  echo "    logs in $LOGDIR"
else
  echo "[✓] all modules built. .ko in $DIST"
fi
