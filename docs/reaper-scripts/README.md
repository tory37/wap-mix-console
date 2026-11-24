# REAPER scripts

Lua ReaScripts for the WAP mix. Pure REAPER API. No SWS or JS extension.

## Install

1. Choose **Actions** > **Show action list** > **New action** > **Load ReaScript**.
2. Select the `.lua` file.
3. Optional: select the script in the action list. Click **Add** under Shortcuts and press a key.

## Scripts

| Script | What it does |
|---|---|
| `wap_build_mix_template.lua` | Builds the full WAP template from the Routing page: tracks, folders, sends, sidechain hubs, names, group colors, pans and widths. Panned mono sources get stereo pan mode with width `0`. Sets the `fx_crush` return fader to `-16 dB` and the `fx_vox_dly` throw send to `-inf`. No plugins. The `ggd_drums` track gets 64 channels and 16 pre-fader sends (`-10 dB`) into the kit tracks, as in the reference project; insert GetGood Drums on it. Hubs have Master/Parent Send off and key channels `3/4` (`sc_spotlight` on `gtr_rhy_bus`: `5/6`). **Update mode:** if any track name matches the template, it updates the project in place. It lists every difference (channels, parent send, color, spacer, pan, width, template fader levels, sends, missing tracks), then asks: Yes = apply all, No = review each (Yes / No / Cancel per change), Cancel = stop. Missing tracks go in at the template level; existing tracks keep their folders. Names used more than once are left alone. Never deletes tracks or sends, never touches plugins. If tracks exist but none match, asks to append (Yes = append, No = cancel). Edit the `TEMPLATE` table at the top to change the layout. One undo step. Prints a report to the ReaScript console. |
| `wap_normalize_tracks_common_gain.lua` | Per track, applies one gain to all audio items so the loudest item peaks at `-10 dBFS`. Changes take volume only, so clip-gain rides and item balance stay. Skips MIDI, empty and silent items. Runs on every track. Switches at the top of the file: `ONLY_SELECTED_TRACKS` and `SKIP_DI_TRACKS` (off by default; turn DI skip on if the amps are already dialed). One undo step. Prints a report to the ReaScript console. |
