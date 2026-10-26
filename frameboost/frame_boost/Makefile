# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2018-2020 Oplus. All rights reserved.

GCOV_PROFILE := y
LINUXINCLUDE += -I$(srctree)/

obj-$(CONFIG_OPLUS_FEATURE_FRAME_BOOST) += oplus_bsp_frame_boost.o
oplus_bsp_frame_boost-y := frame_boost.o frame_sysctl.o frame_info.o frame_group.o cluster_boost.o frame_debug.o
ccflags-y += -I$(src)
ccflags-y += -DCONFIG_OPLUS_SYSTEM_KERNEL_QCOM=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_FRAME_BOOST=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_SCHED_ASSIST=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_SCHED_DDL=1
ccflags-y += -DCONFIG_OPLUS_SCHED_GROUP_OPT=1
ccflags-y += -DCONFIG_OPLUS_CPU_AUDIO_PERF=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_LOADBALANCE=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_PIPELINE=1
ccflags-y += -DCONFIG_BLOCKIO_UX_OPT=1
