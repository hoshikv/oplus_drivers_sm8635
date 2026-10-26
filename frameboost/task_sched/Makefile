# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2021-2023 Oplus. All rights reserved.

GCOV_PROFILE := y
obj-$(CONFIG_OPLUS_FEATURE_TASK_SCHED) += oplus_bsp_task_sched.o

oplus_bsp_task_sched-y := task_sched_info.o

# OnePlus sources include kernel-internal headers via relative angle-includes
# that only resolve when the module builds from inside the kernel tree:
#   <../fs/proc/internal.h>             -> -I$(srctree)/ .. w/ fs symlink
#   <../kernel/sched/sched.h>           -> -I$(srctree)/
#   <../kernel/oplus_cpu/...>           -> -I$(srctree)/
ccflags-y += -I$(srctree)/
ccflags-y += -I$(srctree)/..
ccflags-y += -I$(src)
ccflags-y += -DCONFIG_OPLUS_SYSTEM_KERNEL_QCOM=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_TASK_SCHED=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_SCHED_ASSIST=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_SCHED_DDL=1
ccflags-y += -DCONFIG_OPLUS_SCHED_GROUP_OPT=1
ccflags-y += -DCONFIG_OPLUS_CPU_AUDIO_PERF=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_LOADBALANCE=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_PIPELINE=1
ccflags-y += -DCONFIG_BLOCKIO_UX_OPT=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_FRAME_BOOST=1
