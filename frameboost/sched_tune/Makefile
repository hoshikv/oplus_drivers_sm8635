GCOV_PROFILE := y
LINUXINCLUDE += -I$(srctree)/

obj-$(CONFIG_OPLUS_SCHED_TUNE) += oplus_bsp_schedtune.o
oplus_bsp_schedtune-y += tune.o
ccflags-y += -I$(src)
ccflags-y += -DCONFIG_OPLUS_SYSTEM_KERNEL_QCOM=1
ccflags-y += -DCONFIG_OPLUS_SCHED_TUNE=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_SCHED_ASSIST=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_SCHED_DDL=1
ccflags-y += -DCONFIG_OPLUS_SCHED_GROUP_OPT=1
ccflags-y += -DCONFIG_OPLUS_CPU_AUDIO_PERF=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_LOADBALANCE=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_PIPELINE=1
ccflags-y += -DCONFIG_BLOCKIO_UX_OPT=1
ccflags-y += -DCONFIG_OPLUS_FEATURE_FRAME_BOOST=1
oplus_bsp_schedtune-y += license.o
