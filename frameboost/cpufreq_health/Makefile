GCOV_PROFILE := y

# Provide the config as a C preprocessor macro (needed by IS_ENABLED() in
# cpufreq_health.h); otherwise the header's #else branch emits a stub
# static-inline definition that clashes with our real implementation.
ccflags-y += -DCONFIG_OPLUS_FEATURE_OCH=1

obj-$(CONFIG_OPLUS_FEATURE_OCH) += oplus_bsp_cpufreq_health.o
oplus_bsp_cpufreq_health-y := cpufreq_health.o
