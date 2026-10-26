# SPDX-License-Identifier: GPL-2.0-only
# Copyright (C) 2022 Oplus. All rights reserved.

GCOV_PROFILE := y
LINUXINCLUDE += -I$(srctree)/

obj-$(CONFIG_OPLUS_FEATURE_GAME_OPT) += oplus_bsp_game_opt.o

oplus_bsp_game_opt-y := cpu_load.o cpufreq_limits.o critical_task_boost.o debug.o early_detect.o fake_cpufreq.o frame_load.o frame_sync.o game_ctrl.o rt_info.o task_util.o yield_opt.o

oplus_bsp_game_opt-y += task_boost/boost_proc.o task_boost/heavy_task_boost.o
ccflags-y += -I$(src)
