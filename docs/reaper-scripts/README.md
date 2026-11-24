# REAPER scripts

Lua ReaScripts for the WAP mix. Pure REAPER API. No SWS or JS extension.

## Install

1. Choose **Actions** > **Show action list** > **New action** > **Load ReaScript**.
2. Select the `.lua` file.
3. Optional: select the script in the action list. Click **Add** under Shortcuts and press a key.

## Scripts

| Script | What it does |
|---|---|
| `wap_build_mix_template.lua` | Builds the full WAP template from the Routing page: tracks, folders, sends, sidechain hubs, names and group colors. No plugins. The `ggd_drums` track gets 64 channels and 16 pre-fader sends (`-10 dB`) into the kit tracks, as in the reference project; insert GetGood Drums on it. Hubs have Master/Parent Send off and key channels `3/4` on 4-channel targets. If the project has tracks, asks first (Yes = append, No = cancel); never deletes tracks. Edit the `TEMPLATE` table at the top to change the layout. One undo step. Prints a report to the ReaScript console. |
| `wap_normalize_tracks_common_gain.lua` | Per track, applies one gain to all audio items so the loudest item peaks at `-10 dBFS`. Changes take volume only, so clip-gain rides and item balance stay. Skips MIDI, empty and silent items. Runs on every track. Switches at the top of the file: `ONLY_SELECTED_TRACKS` and `SKIP_DI_TRACKS` (off by default; turn DI skip on if the amps are already dialed). One undo step. Prints a report to the ReaScript console. |
