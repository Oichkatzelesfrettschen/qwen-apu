# Commanding FCLK 1067 on Raven2: the driver already sends it and the firmware holds 933

`dpm-authority/README.md` measures three settings that all fail to hold the
fabric clock at the 1067 MHz step `pp_dpm_mclk` advertises, and
`dpm-authority-design.md` registers a kernel hypothesis for why. This file
reads the running kernel's own SMU10 powerplay source and the appliance's own
sysfs state against that hypothesis, and it changes the answer in one place
that matters: the `manual` level-3 write is not a min-only request, so the
route that would have been tried first is already exhausted by the write the
appliance has been making.

## Findings

**`smu10_force_clock_level` writes both the hard minimum and the soft maximum
for `PP_MCLK`, at the requested table entry's own frequency.** A write of `3`
to `pp_dpm_mclk` becomes mask `0x8` through `amdgpu_read_mask`, so `low` and
`high` both resolve to 3 and the driver sends
`PPSMC_MSG_SetHardMinFclkByFreq(1067)` followed by
`PPSMC_MSG_SetSoftMaxFclkByFreq(1067)`. The empty `mclk3.err` in
`dpm-authority/20260902T2002Z-fclk-level3/` proves both messages were issued:
`pp_dpm_force_clock_level` returns `-EINVAL` when `hwmgr->dpm_level` is
anything other than `AMD_DPM_FORCED_LEVEL_MANUAL`, so a success return means
the backend ran. The 933 MHz the sampler reads back through
`PPSMC_MSG_GetFclkFrequency` is therefore the firmware declining a
well-formed, in-table request for both bounds, rather than a driver that
raised the floor and left the ceiling low. Route (a) of the reviewer's list is
closed by the same reading that was expected to open it.

**`high` and `profile_peak` send an unclamped 1200 MHz, and the driver never
compares it to the platform table.** Both arms of `smu10_dpm_force_dpm_level`
pass `SMU10_UMD_PSTATE_PEAK_FCLK` -- a compile-time 1200 -- to
`SetHardMinFclkByFreq` and `SetSoftMaxFclkByFreq`, while `index_fclk`, the
table's own top index, is already computed six lines above and used only by the
`auto` arm. The reviewer's hypothesis is confirmed on its driver half: no
clamp exists. Its firmware half stays inference, and the observed 400 MHz is
ambiguous between two readings, since 400 equals both
`SMU10_UMD_PSTATE_MIN_FCLK` and `vdd_dep_on_fclk->entries[1].clk / 100`.

**`auto` is the only setting whose fabric request is satisfiable at the top of
the table.** Its soft maximum is
`vdd_dep_on_fclk->entries[index_fclk].clk / 100`, which is 1067 on this
platform, and its hard minimum is the display configuration's own value
clamped up to `clock_table.FClocks[0].Freq`. That is why retained `auto`
telemetry reaches 1067 where the two forced levels collapse to 400.

**The load-driven reading of `auto`'s 1067 is itself now in question.** The
finest-grained fabric sampling this campaign holds --
`20260902T2002Z-fclk-level3/samples.tsv`, 50 ms rows -- reads 1067 on 8 of its
145 rows overall and on only 2 of the 107 rows above its own busy threshold,
so within that run the excursions are *less* frequent under GPU load than
outside it. Every "`auto` selects 1067 under sustained load" observation this
tree carries comes from a different run, load state, and sampling window than
the `manual` arms it is contrasted with, and none of them samples the fabric
clock at 50 ms across a load boundary. The contrast the section below draws
between a satisfiable `auto` request and an unsatisfiable forced one is
established on the driver side and unestablished on the delivery side, which
is why the next experiment mirrors the two settings inside one session.

**The FCLK table is the firmware's, not the driver's.**
`smu10_get_clock_table` copies `DpmClocks_t` out of the SMU through
`smum_smc_table_manager(hwmgr, table, SMU10_CLOCKTABLE, true)` and
`smu10_get_clock_voltage_dependency_table` turns `FClocks[0..3]` into
`vdd_dep_on_fclk`. The `0 / 400 / 933 / 1067` ladder the appliance prints is
what this SKU's PMFW advertises. A hypothetical 1200 MHz entry is not a value
any Linux-side setting can add.

**No `ppfeaturemask` bit gates FCLK on this backend.** `smu10_hwmgr.c` reads
`adev->pm.pp_feature` at exactly two sites, both testing `PP_GFXOFF_MASK`.
`PP_MCLK_DPM_MASK` is never consulted here. The appliance's `0xfff7bfff` is
byte-identical to `amdgpu_drv.c`'s own default, so the machine already runs
the stock feature set with `PP_OVERDRIVE_MASK` (0x4000) and `PP_GFX_DCS_MASK`
(0x80000) cleared and everything else set. A module reload with a different
mask has no FCLK lever to reach.

**The fine-grain surface carries no FCLK control.** `hwmgr->od_enabled = 1`
unconditionally in `smu10_hwmgr_backend_init`, which is why the appliance
prints `OD_SCLK` and `OD_RANGE` despite `PP_OVERDRIVE_MASK` being clear, and
`smu10_set_fine_grain_clk_vol` handles `PP_OD_EDIT_SCLK_VDDC_TABLE` alone. The
appliance's own `pp_od_clk_voltage` reads `OD_SCLK: 0: 200Mhz / 1: 1100Mhz`
with `OD_RANGE: SCLK: 200MHz 1100MHz` and names no fabric range.

## Appliance state

Read over SSH on `qwen-laptop`, sysfs and `sudo -n` reads only; nothing here
wrote a module parameter, loaded a driver, or rebooted.

| property | value |
| --- | --- |
| distribution | Linux Mint 22.2 (Zara) |
| kernel | `7.0.0-29-generic` |
| device | `amdgpu 0000:04:00.0`, `RAVEN 0x1002:0x15D8 0x103C:0x879E 0xCD`, ATOM BIOS `113-RAVEN2-117` |
| power IP block | `smu_v1_0_0 (powerplay)`, `hwmgr_sw_init smu backed is smu10_smu` |
| `ppfeaturemask` | `0xfff7bfff` |
| `bapm` | `-1` |
| `power_dpm_force_performance_level` | `auto` |
| `pp_dpm_mclk` | `0: 0Mhz`, `1: 400Mhz`, `2: 933Mhz *`, `3: 1067Mhz` |
| `pp_dpm_sclk` | `0: 200Mhz`, `1: 400Mhz *`, `2: 1100Mhz` |
| `pp_dpm_fclk`, `pp_dpm_socclk` | present and empty |
| `pp_features` | absent; the swSMU node does not exist on the powerplay path |
| `pp_power_profile_mode` | `0 BOOTUP_DEFAULT*` of six modes |

`0xfff7bfff` decodes against `enum PP_FEATURE_MASK` as every bit set except
`PP_OVERDRIVE_MASK` (0x4000) and `PP_GFX_DCS_MASK` (0x80000), and
`amdgpu_drv.c` line 202 reads `uint amdgpu_pp_feature_mask = 0xfff7bfff;`, so
the appliance carries the driver default with no kernel command line override.

`/sys/kernel/debug/dri/0000:04:00.0/amdgpu_pm_info` at idle reports
`933 MHz (MCLK)`, `400 MHz (SCLK)`, `700 MHz (PSTATE_SCLK)`,
`933 MHz (PSTATE_MCLK)`, `GPU Load: 4 %`. The two PSTATE figures are
`SMU10_UMD_PSTATE_GFXCLK` and `SMU10_UMD_PSTATE_FCLK` read back through
`hwmgr->pstate_sclk` and `hwmgr->pstate_mclk`; the MCLK line is
`PPSMC_MSG_GetFclkFrequency`, the same read `pp_dpm_mclk` stars.

`dmesg` carries three PSP `LOAD_IP_FW` failures for the RLC save-and-restore
lists (`RLC_RESTORE_LIST_CNTL`, `_GPM_MEM`, `_SRM_MEM`, responses `0xFFFF300F`
and `0xFFFF000F`) and `RAS: optional ras ta ucode is not available`. Those
concern GFXOFF's save-and-restore path, not the fabric clock, and they are
recorded here because they are the only powerplay-adjacent errors the boot log
holds.

## Source, at the running kernel's version

The appliance runs `7.0.0-29-generic`, so the quotations below are taken from
the `v7.0` tag. A `PEAK_FCLK` / `SetHardMinFclkByFreq` / `SetSoftMaxFclkByFreq`
grep of the same file at `master` differs from `v7.0` only in line numbers, so
the mechanism is not a version artifact and a newer kernel changes none of it.

### The forced levels send a constant the table cannot satisfy

`drivers/gpu/drm/amd/pm/powerplay/hwmgr/smu10_hwmgr.c`,
`smu10_dpm_force_dpm_level`, entry (line 631):

```c
	uint32_t index_fclk = data->clock_vol_info.vdd_dep_on_fclk->count - 1;
	uint32_t index_socclk = data->clock_vol_info.vdd_dep_on_socclk->count - 1;
```

The same function, `AMD_DPM_FORCED_LEVEL_HIGH` and
`AMD_DPM_FORCED_LEVEL_PROFILE_PEAK` (lines 646 to 690, abridged to the fabric
messages):

```c
	case AMD_DPM_FORCED_LEVEL_HIGH:
	case AMD_DPM_FORCED_LEVEL_PROFILE_PEAK:
		...
		smum_send_msg_to_smc_with_parameter(hwmgr,
						PPSMC_MSG_SetHardMinFclkByFreq,
						SMU10_UMD_PSTATE_PEAK_FCLK,
						NULL);
		...
		smum_send_msg_to_smc_with_parameter(hwmgr,
						PPSMC_MSG_SetSoftMaxFclkByFreq,
						SMU10_UMD_PSTATE_PEAK_FCLK,
						NULL);
		break;
```

`index_fclk` is in scope and unused by this arm. No comparison against
`vdd_dep_on_fclk` stands between the constant and the mailbox.

The same function, `AMD_DPM_FORCED_LEVEL_AUTO` (lines 780 to 806, abridged):

```c
		smum_send_msg_to_smc_with_parameter(hwmgr,
						PPSMC_MSG_SetHardMinFclkByFreq,
						hwmgr->display_config->num_display > 3 ?
						(data->clock_vol_info.vdd_dep_on_fclk->entries[0].clk / 100) :
						min_mclk,
						NULL);
		...
		smum_send_msg_to_smc_with_parameter(hwmgr,
						PPSMC_MSG_SetSoftMaxFclkByFreq,
						data->clock_vol_info.vdd_dep_on_fclk->entries[index_fclk].clk / 100,
						NULL);
```

`AMD_DPM_FORCED_LEVEL_PROFILE_STANDARD` sends `SMU10_UMD_PSTATE_FCLK` to both,
and `AMD_DPM_FORCED_LEVEL_PROFILE_MIN_MCLK` sends `min_mclk` to both.

### The constants

`drivers/gpu/drm/amd/pm/powerplay/hwmgr/smu10_hwmgr.h`, lines 312 to 322:

```c
#define SMU10_UMD_PSTATE_GFXCLK                 700
#define SMU10_UMD_PSTATE_SOCCLK                 626
#define SMU10_UMD_PSTATE_FCLK                   933
...
#define SMU10_UMD_PSTATE_PEAK_SOCCLK            757
#define SMU10_UMD_PSTATE_PEAK_FCLK              1200
...
#define SMU10_UMD_PSTATE_MIN_FCLK               400
```

`SMU10_UMD_PSTATE_FCLK` is 933 and the appliance's delivered fabric clock is
933 under every `manual` arm measured, which is a coincidence of value rather
than a code path: nothing in `smu10_force_clock_level` reads that constant.

`smu10_populate_umdpstate_clocks` also publishes the same 1200 as the reported
peak (line 385):

```c
	hwmgr->pstate_mclk_peak = SMU10_UMD_PSTATE_PEAK_FCLK;
```

so a patch that changes only the forced-level arms leaves the reported peak
disagreeing with the commanded one.

### The manual write sends both bounds

`smu10_force_clock_level`, `PP_MCLK` (lines 1003 to 1017):

```c
	case PP_MCLK:
		if (low > mclk_table->count - 1 || high > mclk_table->count - 1)
			return -EINVAL;

		smum_send_msg_to_smc_with_parameter(hwmgr,
						PPSMC_MSG_SetHardMinFclkByFreq,
						mclk_table->entries[low].clk/100,
						NULL);

		smum_send_msg_to_smc_with_parameter(hwmgr,
						PPSMC_MSG_SetSoftMaxFclkByFreq,
						mclk_table->entries[high].clk/100,
						NULL);
		break;
```

with `low` and `high` derived at the top of the same function:

```c
	low = mask ? (ffs(mask) - 1) : 0;
	high = mask ? (fls(mask) - 1) : 0;
```

and `mclk_table` bound to `data->clock_vol_info.vdd_dep_on_fclk`.

The mask comes from `drivers/gpu/drm/amd/pm/amdgpu_pm.c`, `amdgpu_read_mask`:

```c
	while ((sub_str = strsep(&tmp, delimiter)) != NULL) {
		if (strlen(sub_str)) {
			ret = kstrtoul(sub_str, 0, &level);
			if (ret || level > 31)
				return -EINVAL;
			*mask |= 1 << level;
		} else
			break;
	}
```

A single-token write of `3` therefore yields mask `0x8`, `low == high == 3`,
and both messages carrying `entries[3].clk / 100` = 1067.
`remote/census-arm-lib.sh`'s `census_engine_clock_select` writes exactly one
index token through `printf '%s\n' "$1" | sudo -n tee`, so the appliance has
been issuing the single-level form rather than a range. A range write such as
`0 1 2 3` would yield `low == 0` and a hard minimum of 0 MHz, which is a
different request and is not what any retained run made.

`pp_dpm_force_clock_level` in
`drivers/gpu/drm/amd/pm/powerplay/amd_powerplay.c` is the gate the empty
`mclk3.err` clears:

```c
	if (hwmgr->dpm_level != AMD_DPM_FORCED_LEVEL_MANUAL) {
		pr_debug("force clock level is for dpm manual mode only.\n");
		return -EINVAL;
	}
```

### What the readback measures

`smu10_print_clock_levels`, `PP_MCLK` (lines 1061 to 1072):

```c
	case PP_MCLK:
		ret = smum_send_msg_to_smc(hwmgr, PPSMC_MSG_GetFclkFrequency, &now);
		if (ret)
			return ret;

		for (i = 0; i < mclk_table->count; i++)
			size += sysfs_emit_at(
				buf, size, "%d: %uMhz %s\n", i,
				mclk_table->entries[i].clk / 100,
				((mclk_table->entries[i].clk / 100) == now) ?
					"*" :
					"");
```

and `smu10_read_sensor` answers `AMDGPU_PP_SENSOR_GFX_MCLK` from the same
message. The star is an equality test against a live firmware report, so a
starred 933 means the SMU returned exactly 933, and an unstarred table means
the SMU returned a value the table does not carry.

`rv_ppsmc.h` fixes the ids: `PPSMC_MSG_SetHardMinFclkByFreq 0x12`,
`PPSMC_MSG_SetSoftMaxFclkByFreq 0x33`, `PPSMC_MSG_GetFclkFrequency 0x2B`,
`PPSMC_MSG_SetAllowFclkSwitch 0x13`.

### Where the table comes from

`smu10_get_clock_table` (lines 500 to 518, abridged):

```c
	result = smum_smc_table_manager(hwmgr, (uint8_t *)table, SMU10_CLOCKTABLE, true);
	...
	if (0 == result && table->DcefClocks[0].Freq != 0) {
		...
		smu10_get_clock_voltage_dependency_table(hwmgr, &pinfo->vdd_dep_on_fclk,
						NUM_FCLK_DPM_LEVELS,
						&smu10_data->clock_table.FClocks[0]);
```

`smu10_get_clock_voltage_dependency_table` copies `Freq * 100` per entry with
no filtering, so `0 / 400 / 933 / 1067` including the zero-valued slot 0 is
verbatim firmware content.

## Mechanism for each observed behavior

**`manual` level 3 holds 933.** The driver's request is a hard minimum and a
soft maximum both at 1067 MHz, in-table and accepted without error. The
firmware answers `GetFclkFrequency` with 933 anyway. Two accounts remain open
and this file separates them rather than choosing.

The first is a firmware refusal: SMU10 PMFW treats 1067 as reachable
opportunistically under its own DF arbitration but declines to hold it as a
floor, so the hard minimum lands somewhere at or below 933 and the soft
maximum permits the excursions the sampler sees. The evidence consistent with
this is that `20260902T2002Z-fclk-level3/samples.tsv` reads 933 on its very
first row, before the decode begins, so no interval of a held 1067 was ever
observed.

The second is a driver-side rescind. `smu10_force_clock_level` sends
`SetHardMinFclkByFreq` directly and never updates
`smu10_data->f_actual_hard_min_freq`, while both
`smu10_set_hard_min_fclk_by_freq` and the display path's
`amd_pp_f_clock` case return early on `clk_freq == f_actual_hard_min_freq`:

```c
static int smu10_set_hard_min_fclk_by_freq(struct pp_hwmgr *hwmgr, uint32_t clock)
{
	struct smu10_hwmgr *smu10_data = (struct smu10_hwmgr *)(hwmgr->backend);

	if (clock && smu10_data->f_actual_hard_min_freq != clock) {
		smu10_data->f_actual_hard_min_freq = clock;
		smum_send_msg_to_smc_with_parameter(hwmgr,
					PPSMC_MSG_SetHardMinFclkByFreq,
					smu10_data->f_actual_hard_min_freq,
					NULL);
	}
	return 0;
}
```

The manual write leaves that cache stale, so the next display clock request
carrying a lower value passes the inequality and re-sends a lower hard minimum,
silently rescinding the pin while the soft maximum of 1067 survives. This
account predicts an interval of held 1067 between the write and the first
display request. The retained sampler cannot see that interval: its first row
already reads 933, and the elapsed time between the `pp_dpm_mclk` write and
that row is not recorded in the run. The account is therefore untested rather
than refuted, and a sampler started before the write settles it.

The 1067 excursions the run does carry order with neither account. Rows 15 to
17 and 32 to 33 read 1067 at `gpu_busy_percent` of 8 to 22, and rows 135 and
142 to 143 read it at 90, 51, and 26. Eight of 145 rows overall against 2 of
the 107 rows above the run's own busy threshold means the excursions are less
frequent inside the busy window than outside it, which cuts against GPU load
driving the fabric clock up.

**`high` and `profile_peak` fall to 400.** The driver sends an unclamped 1200
to both bounds and the firmware answers 400. The driver half is established
from source: the constant is compile-time, `index_fclk` is computed and
unused, and no clamp exists. The firmware half is inference, and 400 is
ambiguous between the table's lowest nonzero entry and `SMU10_UMD_PSTATE_MIN_FCLK`,
which are the same number. The design note's package-power alternative -- that
pinning GFXCLK at 1100 under BAPM leaves the fabric no budget -- is not
excluded by anything read here, because both arms also send
`SetHardMinGfxClk(gfx_max_freq_limit/100)` and `SetSoftMaxGfxClk` of the same,
so the fabric fall is confounded with a graphics pin in every retained arm.

**`auto` selects 1067 under sustained load.** Its soft maximum is the table's
own top entry rather than a constant, so it is the only setting whose request
the firmware can satisfy at 1067, and its hard minimum stays low enough that
the DF arbitrates freely between 400 and 1067. Retained `auto` telemetry
reaching 1067 is that arbitration, not a commanded state.

**Why the constant is 1200.** 1067 MHz is 2133.33 / 2, the fabric running
1:1 with this machine's trained DDR4-2133.33 memory clock
(`evidence/measurement-state-and-memory-clock.md`). 1200 MHz is 2400 / 2, the
1:1 point for the DDR4-2400 configurations AMD's Raven reference platforms
carried. The constant reads as a reference-platform value that this SKU's
table does not reach. That is an origin story for the number and not a
coupling rule: 933 is not memory-derived, and no source read here states that
FCLK tracks the memory clock on this part.

## Routes to a commanded 1067, ranked by intervention size

| # | route | intervention | reversibility | verdict |
| --- | --- | --- | --- | --- |
| 1 | `manual` with both bounds at level 3 | one sysfs write, already made | immediate | exhausted: the driver already sends both |
| 2 | a sampler started before the write | one harness change, sysfs only | immediate | diagnostic rather than a lever: it decides which of routes 1 and 5 the defect belongs to |
| 3 | `ppfeaturemask` module parameter | module reload or reboot | reboot | empty: no bit reaches FCLK on this backend |
| 4 | `pp_od_clk_voltage` fine grain | one sysfs write | immediate | empty: the smu10 OD surface is GFXCLK only |
| 5 | kernel patch replacing the 1200 constant | build, install, reboot | reboot to the packaged kernel | the registered falsifier, and the only clean route |
| 6 | `ryzen_smu` raw mailbox | load an out-of-tree driver | unload, but the SMU state persists | unsound: undocumented namespace, unarbitrated |
| 7 | BIOS or DIMM change | firmware setting or hardware swap | hardware | empty: the table is firmware-reported and the DIMMs are 2133 parts |

### Route 1 -- `manual` with a hard minimum and a soft maximum at level 3

```sh
echo manual | sudo tee /sys/class/drm/card1/device/power_dpm_force_performance_level
echo 2      | sudo tee /sys/class/drm/card1/device/pp_dpm_sclk
echo 3      | sudo tee /sys/class/drm/card1/device/pp_dpm_mclk
```

This is the write `20260902T2002Z-fclk-level3` already made, and the source
above shows it sending both `SetHardMinFclkByFreq(1067)` and
`SetSoftMaxFclkByFreq(1067)`. There is no separate min-and-max form to try:
the single-index write is the both-bounds form, and a multi-index write is
strictly weaker because `low` would then resolve to a lower entry. Readback:
the starred `pp_dpm_mclk` line, which is `PPSMC_MSG_GetFclkFrequency` compared
against the table. Falsifier already met: 933 MHz on 105 of 107 busy rows.

### Route 2 -- sample the fabric clock across the write

The one experiment that separates the firmware-refusal account from the
driver-rescind account, at zero intervention beyond harness order. Start the
50 ms sampler, record its first timestamp, issue the `pp_dpm_mclk` level-3
write, and keep sampling through an idle interval and then a decode.
Readback: the starred `pp_dpm_mclk` line per sample, with the write's own
timestamp on the same clock. Falsifier: a sustained 1067 in the samples
immediately after the write that later decays to 933 supports the rescind
account and makes `f_actual_hard_min_freq` the defect; a first post-write
sample already at 933 supports the firmware-refusal account and makes route 5
the only remaining lever.

### Route 3 -- `ppfeaturemask`

```sh
# not run; requires a module reload or a kernel command line and a reboot
sudo modprobe -r amdgpu && sudo modprobe amdgpu ppfeaturemask=0xffffffff
```

`smu10_hwmgr.c` consults `adev->pm.pp_feature` only for `PP_GFXOFF_MASK`, so
no mask value changes what the fabric path sends. Setting
`PP_OVERDRIVE_MASK` back on changes nothing either, because `od_enabled` is
already 1 unconditionally. Route recorded as closed rather than untried.

### Route 4 -- fine grain

`smu10_set_fine_grain_clk_vol` implements `PP_OD_EDIT_SCLK_VDDC_TABLE` and
`PP_OD_COMMIT_DPM_TABLE`, and the appliance's `OD_RANGE` names `SCLK` alone.
No fabric range is exposed and no `OD_FCLK` token is parsed. Closed.

### Route 5 -- the kernel patch

Both sites in `drivers/gpu/drm/amd/pm/powerplay/hwmgr/smu10_hwmgr.c` need the
change, because `smu10_populate_umdpstate_clocks` publishes the peak that
`pp_dpm_force_performance_level` documentation and any consumer of
`hwmgr->pstate_mclk_peak` reports:

```c
	/* smu10_dpm_force_dpm_level, HIGH and PROFILE_PEAK arms:
	   index_fclk is already in scope at the top of the function */
-						SMU10_UMD_PSTATE_PEAK_FCLK,
+						data->clock_vol_info.vdd_dep_on_fclk->entries[index_fclk].clk / 100,

	/* smu10_populate_umdpstate_clocks */
-	hwmgr->pstate_mclk_peak = SMU10_UMD_PSTATE_PEAK_FCLK;
+	hwmgr->pstate_mclk_peak =
+		((struct smu10_hwmgr *)hwmgr->backend)->clock_vol_info
+			.vdd_dep_on_fclk->entries[
+			((struct smu10_hwmgr *)hwmgr->backend)->clock_vol_info
+				.vdd_dep_on_fclk->count - 1].clk / 100;
```

The second hunk's dereference is safe in that order: `smu10_populate_clock_table`
runs at line 565 inside `smu10_hwmgr_backend_init`, and
`smu10_populate_umdpstate_clocks` runs at line 411 inside
`smu10_enable_dpm_tasks`, which the hwmgr registers as
`.dynamic_state_management_enable` and calls after `.backend_init`. So
`clock_vol_info.vdd_dep_on_fclk` is populated before the peak is published.
A patch reordered against a later kernel needs that ordering checked again,
because the hunk turns a compile-time constant into a pointer dereference.

The precedent is AMD's own: the amd-gfx series
"drm/amdgpu/swSMU: custom UMD pstate peak clock for navi14" exists because a
hard-coded UMD pstate peak did not match a particular SKU, and the fix was to
derive the value rather than to add a second constant.

Cost on the appliance is a build and a reboot, and both are session-ending:
`amdgpu` is in-tree on this distribution, so the build path is an open
question between a full kernel source package and a DKMS out-of-tree copy of
the amdgpu subtree, and neither has been established here. The two 2.3 GHz
cores and the resident VM tenant make a full kernel build contend with the
appliance's own serving window. Readback: the starred `pp_dpm_mclk` line under
`high`, plus `PPSMC_MSG_GetFclkFrequency` through `amdgpu_pm_info`, plus
decode tok/s under a pinned GFXCLK of 1100 as the outcome the campaign
actually cares about. Falsifier as the design note registers it: a patched
`high` delivering 1067 sustained through a decode window at 50 ms sampling
confirms the unsatisfiable-request mechanism; a patched `high` still falling
to 400 or holding 933 moves the mechanism to the package-power layer and
retires the constant as the explanation.

### Route 6 -- `ryzen_smu`

`$HOME/src/ryzen_smu` on the appliance is at `d298366`, is built
(`ryzen_smu.ko` present), and is not loaded: `/sys/kernel/ryzen_smu_drv/` does
not exist. Its README lists Raven Ridge 2 among supported code names and its
sysfs surface as `smu_args`, `mp1_smu_cmd`, `rsmu_cmd`, `hsmp_smu_cmd`, and
`smn`, all root-only, so a caller writes six arguments and then a command id
to a mailbox.

Two facts rank this route below the kernel patch rather than above it.

The message namespace is undocumented for this part. `docs/rsmu_commands.md`
carries a two-entry global set (`TestMessage 0x01`, `GetSMUVersion 0x02`) and
per-family tables for Matisse, Vermeer and their relatives; it names Raven
nowhere. `rv_ppsmc.h`'s `0x12` and `0x33` belong to the graphics driver's own
PPSMC namespace, and nothing establishes that the mailbox `ryzen_smu` writes
interprets those ids the same way. Writing an id whose meaning on that mailbox
is unknown is an unbounded action against a power controller.

The mailboxes are distinct registers on one microcontroller. `ryzen_smu`
selects, for `CODENAME_RAVENRIDGE2`, an MP1 mailbox at SMN `0x3B10528` /
`0x3B10564` / `0x3B10998` and an RSMU mailbox at `0x3B10A20` / `0x3B10A80` /
`0x3B10A88`, reached through the root complex's SMN index and data pair.
`smu10_smumgr.c` reaches `mmMP1_SMN_C2PMSG_66`, `_82`, and `_90` through the
GPU's own MMIO register window. Different register pairs, so no direct
collision, and the same MP1 firmware behind all of them, so a command issued
while `amdgpu` has one in flight interleaves at the firmware level with no
arbitration between the two drivers. `ryzen_smu`'s `smn` attribute is a third
route -- arbitrary SMN reads and writes, including `amdgpu`'s own C2PMSG
registers -- and it is the least acceptable of the three for the same reason.
Falsifier, were it run: `pp_dpm_mclk` starring 1067 while `amdgpu` reports no
SMU message timeout in `dmesg`. Not proposed.

### Route 7 -- firmware and DIMMs

The FCLK table is copied out of the SMU's own `DpmClocks_t`, so the ceiling is
a PMFW property rather than a Linux setting, and the appliance's consumer
notebook BIOS exposes no fabric or memory ratio control on which to test the
question. The
DDR4-2400 hypothesis behind the 1200 constant is a hardware change rather than
a setting: this machine trains at DDR4-2133.33 from both UMC channels' own SMN
registers and both installed Crucial CT16G4SFD8213 modules are DDR4-2133 parts
by their own SPD EEPROMs, so a 1200 MHz table entry would require 2400-rated
modules and a PMFW that derives the top FCLK step from the trained memory
clock. Neither half is established. Readback, were the modules swapped:
`pp_dpm_mclk` printing a fourth entry above 1067. Falsifier: an unchanged
`0 / 400 / 933 / 1067` table under 2400-rated modules would show the ceiling is
fixed in firmware rather than memory-derived, which would also retire the
origin story for the 1200 constant.

## The next experiment

Run route 2 before anything else, as a single sysfs-only arm on `qwen-laptop`
with the appliance torn down: start the 50 ms fabric sampler, let it record
twenty rows of the `auto` idle state, issue `manual` plus `pp_dpm_sclk` 2 plus
`pp_dpm_mclk` 3 with the write's timestamp on the sampler's own clock, sample
thirty seconds of idle, then run one `llama-bench tg32` decode, then return to
`auto` and sample twenty more rows -- and then run the same shape mirrored as
auto, manual-3, manual-3, auto under one load state so the `auto` arm that
reaches 1067 and the `manual` arm that holds 933 finally meet in one session
rather than in separate runs minutes and hours apart. That single run answers
both open questions at zero risk: a held 1067 immediately after the write that
decays to 933 names `f_actual_hard_min_freq`'s stale cache as the defect and
makes the fix a three-line driver change rather than a constant replacement,
while a first post-write sample already at 933 leaves the firmware as the
authority and makes route 5 the only lever left; and an `auto` arm sustaining
1067 where `manual` level 3 does not confirms that the hard-minimum message
rather than the soft maximum is what the firmware is refusing, which is
exactly the premise route 5's patch rests on. Until that run exists, the
campaign's operating point stays where `dpm-authority/README.md` puts it --
`manual`, GFXCLK at 1100 MHz, FCLK at 933 MHz -- because every alternative
measured so far is slower and the one untried alternative is a reboot.

## Sources

- Linux `v7.0`, `drivers/gpu/drm/amd/pm/powerplay/hwmgr/smu10_hwmgr.c`:
  https://raw.githubusercontent.com/torvalds/linux/v7.0/drivers/gpu/drm/amd/pm/powerplay/hwmgr/smu10_hwmgr.c
- Linux `v7.0`, `drivers/gpu/drm/amd/pm/powerplay/hwmgr/smu10_hwmgr.h`:
  https://raw.githubusercontent.com/torvalds/linux/v7.0/drivers/gpu/drm/amd/pm/powerplay/hwmgr/smu10_hwmgr.h
- Linux `v7.0`, `drivers/gpu/drm/amd/pm/powerplay/inc/rv_ppsmc.h`:
  https://raw.githubusercontent.com/torvalds/linux/v7.0/drivers/gpu/drm/amd/pm/powerplay/inc/rv_ppsmc.h
- Linux `v7.0`, `drivers/gpu/drm/amd/pm/powerplay/smumgr/smu10_smumgr.c`:
  https://raw.githubusercontent.com/torvalds/linux/v7.0/drivers/gpu/drm/amd/pm/powerplay/smumgr/smu10_smumgr.c
- Linux `v7.0`, `drivers/gpu/drm/amd/pm/powerplay/amd_powerplay.c`:
  https://raw.githubusercontent.com/torvalds/linux/v7.0/drivers/gpu/drm/amd/pm/powerplay/amd_powerplay.c
- Linux `v7.0`, `drivers/gpu/drm/amd/pm/amdgpu_pm.c`:
  https://raw.githubusercontent.com/torvalds/linux/v7.0/drivers/gpu/drm/amd/pm/amdgpu_pm.c
- Linux `v7.0`, `drivers/gpu/drm/amd/pm/amdgpu_dpm.c`:
  https://raw.githubusercontent.com/torvalds/linux/v7.0/drivers/gpu/drm/amd/pm/amdgpu_dpm.c
- Linux `v7.0`, `drivers/gpu/drm/amd/include/amd_shared.h`:
  https://raw.githubusercontent.com/torvalds/linux/v7.0/drivers/gpu/drm/amd/include/amd_shared.h
- Linux `v7.0`, `drivers/gpu/drm/amd/amdgpu/amdgpu_drv.c`:
  https://raw.githubusercontent.com/torvalds/linux/v7.0/drivers/gpu/drm/amd/amdgpu/amdgpu_drv.c
- Linux `v7.0`, `drivers/gpu/drm/amd/include/asic_reg/mp/mp_9_0_offset.h`:
  https://raw.githubusercontent.com/torvalds/linux/v7.0/drivers/gpu/drm/amd/include/asic_reg/mp/mp_9_0_offset.h
- Linux `master`, the same `smu10_hwmgr.c`, compared for the FCLK message set:
  https://raw.githubusercontent.com/torvalds/linux/master/drivers/gpu/drm/amd/pm/powerplay/hwmgr/smu10_hwmgr.c
- amd-gfx, "[PATCH] drm/amdgpu/swSMU: custom UMD pstate peak clock for navi14":
  https://lists.freedesktop.org/archives/amd-gfx/2019-October/041105.html
- "GPU Power/Thermal Controls and Monitoring", the kernel's own amdgpu
  documentation for `power_dpm_force_performance_level` and `pp_dpm_mclk`:
  https://www.kernel.org/doc/html/latest/gpu/amdgpu/thermal.html
- `ryzen_smu` at `d298366`, `README.md`, `smu.c`, `drv.c`, and
  `docs/rsmu_commands.md`, read from `$HOME/src/ryzen_smu` on the appliance;
  upstream: https://github.com/amkillam/ryzen_smu
