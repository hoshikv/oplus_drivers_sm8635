# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2025 Oplus. All rights reserved.

LINUXINCLUDE += -I$(srctree)/

obj-$(CONFIG_OPLUS_FEATURE_QOS_SCHED) += oplus_bsp_qos_sched.o
oplus_bsp_qos_sched-y += qos_sched.o
oplus_bsp_qos_sched-y += qos_sched_lut.o
ccflags-y += -I$(src)
ccflags-y += -DCONFIG_OPLUS_SYSTEM_KERNEL_QCOM=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_QOS_SCHED=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_SCHED_ASSIST=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_SCHED_DDL=1
ccflags-y += -DCONFIG_OPLUS_SCHED_GROUP_OPT=1
ccflags-y += -DCONFIG_OPLUS_CPU_AUDIO_PERF=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_LOADBALANCE=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_PIPELINE=1
ccflags-y += -DCONFIG_BLOCKIO_UX_OPT=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_FRAME_BOOST=1
