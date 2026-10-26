# SPDX-License-Identifier: GPL-2.0-only
#
# Kbuild for oplus_bsp_task_load.
#
# The 6.1 OnePlusOSS tree (vendor/oplus/kernel/cpu/sched/task_load/) ships
# task_load.c/task_load.h but no Makefile -- upstream builds it from the
# oplus_performance_5.10 aggregate Makefile instead. This is that Makefile,
# so the module can be built standalone out-of-tree.
#
# Kconfig: CONFIG_OPLUS_FEATURE_TASK_LOAD, default n, depends on
# OPLUS_FEATURE_SCHED_ASSIST.

GCOV_PROFILE := y
obj-$(CONFIG_OPLUS_FEATURE_TASK_LOAD) += oplus_bsp_task_load.o

oplus_bsp_task_load-y := task_load.o

# OnePlus sources include kernel-internal headers via relative angle-includes
# that only resolve when the module builds from inside the kernel tree:
#   <kernel/sched/sched.h>              -> -I$(srctree)/..
#   <../fs/proc/internal.h>             -> $(srctree)/.. w/ fs symlink
#   <../kernel/oplus_cpu/sched/...>     -> -I$(srctree)/
ccflags-y += -I$(srctree)/
ccflags-y += -I$(srctree)/..
ccflags-y += -I$(src)
ccflags-y += -DCONFIG_OPLUS_SYSTEM_KERNEL_QCOM=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_TASK_LOAD=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_SCHED_ASSIST=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_SCHED_DDL=1
ccflags-y += -DCONFIG_OPLUS_SCHED_GROUP_OPT=1
ccflags-y += -DCONFIG_OPLUS_CPU_AUDIO_PERF=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_LOADBALANCE=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_PIPELINE=1
ccflags-y += -DCONFIG_BLOCKIO_UX_OPT=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_FRAME_BOOST=1
