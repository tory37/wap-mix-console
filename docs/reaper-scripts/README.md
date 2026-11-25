# REAPER scripts

Lua ReaScripts for the WAP mix. Pure REAPER API. No SWS or JS extension.

## Install

1. Choose **Actions** > **Show action list** > **New action** > **Load ReaScript**.
2. Select the `.lua` file.
3. Optional: select the script in the action list. Click **Add** under Shortcuts and press a key.

## Scripts

| Script | What it does |
|---|---|
| `wap_build_mix_template.lua` | Builds the full WAP template from the Routing page: tracks, folders, sends, sidechain hubs, names, group colors, pans and widths. Panned mono sources get stereo pan mode with width `0`. Sets the `fx_crush` return fader to `-16 dB`, the snare plate send to `-12 dB`, and the `fx_vox_dly` and `syn_ld` delay throw sends to `-inf`. No plugins. The `ggd_drums` track gets 64 channels and 16 pre-fader sends (`-10 dB`) into the kit tracks, as in the reference project; insert GetGood Drums on it. Hubs have Master/Parent Send off and key channels `3/4` (`sc_spotlight` on `gtr_rhy_bus`: `5/6`). **Update mode:** if any track name matches the template, it updates the project in place. It lists every difference (channels, parent send, color, spacer, pan, width, template fader levels, sends, missing tracks), then asks: Yes = apply all, No = review each (Yes / No / Cancel per change), Cancel = stop. Missing tracks go in at the template level; existing tracks keep their folders. Names used more than once are left alone. Never deletes tracks or sends, never touches plugins. If tracks exist but none match, asks to append (Yes = append, No = cancel). Edit the `TEMPLATE` table at the top to change the layout. One undo step. Prints a report to the ReaScript console. |
| `wap_normalize_tracks_common_gain.lua` | Per track, applies one gain to all audio items so the loudest item peaks at `-10 dBFS`. Changes take volume only, so clip-gain rides and item balance stay. Skips MIDI, empty and silent items. Runs on every track. Switches at the top of the file: `ONLY_SELECTED_TRACKS` and `SKIP_DI_TRACKS` (off by default; turn DI skip on if the amps are already dialed). DI skip matches `bass_di`, `gtr_rhy_l`, `gtr_rhy_r` and any track name ending in `_di`. One undo step. Prints a report to the ReaScript console. |

## Template v1.3 changes

**Vocals:**
- One `vox_ld_dbl` replaces `vox_ld_dbl_bus`, `vox_ld_dbl_l` and `vox_ld_dbl_r`. It sits in `vox_ld_bus`, centered, width `0`. Widen it in choruses with a doubler plugin.
- New `vox_harm_bus` folder in `vox_bgv_bus`. It holds `vox_harm_hi_l` / `vox_harm_hi_r` (pan `±65%`) and `vox_harm_lo_l` / `vox_harm_lo_r` (pan `±40%`). It replaces `vox_harm_hi` and `vox_harm_lo`.
- The `fx_vox_plate` send moves from `vox_ld_bus` to `vox_ld` and `vox_ld_dbl`. Screams keep the slap and the delay throws on `vox_ld_bus`.

**Guitars:**
- `gtr_ld_bus` no longer keys `sc_spotlight`. Only `vox_ld` and `vox_scrm` feed it.
- `gtr_cln_l` and `gtr_oct` pan to `±65%`.
- `gtr_ld` pans to `10% L`, `gtr_ld_harm` to `40% R`.

**FX and synths:**
- `fx_hall` moves out of `orch_syn_bus` to directly under `instrument_bus`. Its sends do not change.
- The `snr_bus` send to `fx_snr_plate` drops from `0 dB` to `-12 dB`. The tom plate send stays at `-10 dB`.
- `syn_ld` gets a post-fader send to `fx_inst_dly` at `-inf`, for automated throws.

**Updating a v1.2 (or older) project:**
- Update mode adds the new tracks and sends, and sets the new pans and send levels.
- The old `vox_ld_dbl_bus`, `vox_ld_dbl_l`, `vox_ld_dbl_r`, `vox_harm_hi` and `vox_harm_lo` stay. The report lists them under "Tracks not in the template".
- Old sends stay too: `vox_ld_bus` to `fx_vox_plate` and `gtr_ld_bus` to `sc_spotlight`. The report lists them under "Sends not in the template".
- An old `fx_hall` stays in `orch_syn_bus`. The report lists it under "Parent differs from the template".
- Nothing is deleted or moved. Move your items to the new tracks by hand. Then delete the old tracks and sends yourself if you want them gone.
