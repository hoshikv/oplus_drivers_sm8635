/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (C) 2022 Oplus. All rights reserved.
 *
 * Stub for the OPLUS cpufreq_health header. The real header lives in the
 * proprietary OnePlus vendor tree (kernel/oplus_cpu/cpufreq_health/), which is
 * not shipped in any OSS release. Peridot has no CONFIG_OPLUS_FEATURE_OCH, so
 * nothing uses symbols from it; the include is kept only to satisfy the
 * unconditional include in uad/cpufreq_uag.h.
 *
 * On a stock OPLUS kernel these symbols are exported from the cpufreq_health
 * subsystem.  Peridot (SM8635) does not carry that code, so we declare them
 * here and provide minimal stubs in cpufreq_uag_main.c.  freq_to_voltage()
 * returns the frequency value as a monotonic proxy for voltage, which keeps
 * the cobuck heuristic working (it only cares about monotonicity).  The bool
 * uaggov_disabled is toggled by governor start/stop and is not referenced
 * outside the uad module in this tree.
 */

#ifndef _LINUX_CPUFREQ_HEALTH_H
#define _LINUX_CPUFREQ_HEALTH_H

#include <linux/types.h>

extern bool uaggov_disabled;
extern unsigned int freq_to_voltage(int cid, unsigned int freq);

#endif /* _LINUX_CPUFREQ_HEALTH_H */
