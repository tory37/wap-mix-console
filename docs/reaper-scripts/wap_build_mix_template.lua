-- @description WAP: build mix template (tracks, folders, routing, names, colors; no plugins)
-- @version 1.2
-- @about Builds the WAP Mix Console template in the current project. Pure REAPER API. Edit the TEMPLATE table to change the layout.
--   On a project that already holds template tracks, it updates them in place and asks before each change.

--------------------------------------------------------------------------------
-- LAYOUT DATA. Edit here; the builder below reads it.
--
-- Track fields:
--   level        indent in the folder tree (0 = top). A track is a folder when
--                the next track has a higher level.
--   name         track name
--   group        color group (see GROUP_COLORS)
--   channels     track channel count, even, 2-128 (default 2)
--   parent_send  false = Master/Parent Send OFF (default true)
--   pan          -1 (left) .. 1 (right) (default 0, center)
--   width        -1 .. 1 (default nil = untouched). Setting it also sets the
--                track to stereo pan mode, so width and pan both apply.
--                Use width = 0 on a panned mono source: a stereo plugin output
--                is then summed and panned, never half-muted by balance pan.
--   volume_db    track fader in dB (default nil = untouched, unity on a new track)
--   sends        list of { to, mode, db, src, dst }
--                  to    destination track name
--                  mode  "post" (post-fader), "pre" (pre-fader, post-FX), "prefx"
--                  db    send level in dB (default 0; SILENT_DB = -inf, for automated throws)
--                  src   source channels: "1/2" stereo, "3" mono, "1-4" multichannel
--                  dst   destination channels: "1/2", "3/4", ... (default "1/2")
--------------------------------------------------------------------------------

local UNDO_LABEL = "WAP: build mix template"
local GGD_TRACK_NAME = "ggd_drums"

-- Track colors as 0xRRGGBB. The sections run down the track list as a rainbow.
local WHITE      = 0xffffff
local FX_GRAY    = 0x8a8a8a
local HUB_BLACK  = 0x000000
local RED        = 0xff0000
local RED_BUS    = 0xc00000
local ORANGE     = 0xff8000
local ORANGE_BUS = 0xc06000
local YELLOW     = 0xffff00
local YELLOW_BUS = 0xc0c000
local GREEN      = 0x00ff00
local GREEN_BUS  = 0x00c000
local BLUE       = 0x0080ff
local BLUE_BUS   = 0x0060c0
local INDIGO     = 0x4000ff
local INDIGO_BUS = 0x3000c0
local VIOLET     = 0xbf00ff
local VIOLET_BUS = 0x9000c0

-- A folder track takes its group's bus shade.
local GROUP_COLORS = {
  white   = { track = WHITE,     bus = WHITE },
  drums   = { track = RED,       bus = RED_BUS },
  bass    = { track = ORANGE,    bus = ORANGE_BUS },
  guitars = { track = YELLOW,    bus = YELLOW_BUS },
  orch    = { track = GREEN,     bus = GREEN_BUS },
  synth   = { track = BLUE,      bus = BLUE_BUS },
  sfx     = { track = INDIGO,    bus = INDIGO_BUS },
  vocals  = { track = VIOLET,    bus = VIOLET_BUS },
  fx      = { track = FX_GRAY,   bus = FX_GRAY },
  hub     = { track = HUB_BLACK, bus = HUB_BLACK },
}

local GGD_OUT_DB = -10  -- reference project: every GGD output send sits at -10 dB
local FX_SEND_DB = -12  -- starting point for creative sends; ride to taste
local TOM_PLATE_DB = -10
local CRUSH_RETURN_DB = -16  -- guide: blend crush under the dry kit, start -14 to -18 dB
local SILENT_DB = -math.huge  -- send at -inf: silent until automated

local function ggd_out(to, src) return { to = to, mode = "pre", db = GGD_OUT_DB, src = src } end
local function key_feed(hub) return { to = hub, mode = "pre", db = 0 } end
local function key_out(target, dst) return { to = target, mode = "pre", db = 0, dst = dst or "3/4" } end
local function fx_send(ret, db) return { to = ret, mode = "post", db = db or FX_SEND_DB } end

local TEMPLATE = {
  -- The mastering chain lives here. REAPER's master track stays empty at unity.
  { level = 0, name = "master_bus",      group = "white" },
  { level = 1, name = "print_bus",       group = "white" },
  { level = 2, name = "instrument_bus",  group = "white", channels = 4 },

  { level = 3, name = "drum_bus",        group = "drums" },
  { level = 4, name = "fx_crush",        group = "fx", volume_db = CRUSH_RETURN_DB },
  { level = 4, name = "fx_snr_plate",    group = "fx" },
  { level = 4, name = "kick_bus",        group = "drums" },
  { level = 5, name = "kick_sum",        group = "drums", sends = { fx_send("fx_crush", 0) } },
  { level = 5, name = "kick_sub",        group = "drums" },  -- no crush: sub energy makes the parallel bus pump
  -- Trigger tracks key the hubs: constant level, no bleed.
  { level = 5, name = "kick_smp",        group = "drums", sends = { key_feed("sc_kick") } },  -- triggers stay out of the crush (Drums page)
  { level = 4, name = "snr_bus",         group = "drums", sends = { fx_send("fx_snr_plate", 0) } },
  { level = 5, name = "snr_top",         group = "drums", sends = { fx_send("fx_crush", 0) } },
  { level = 5, name = "snr_bot",         group = "drums", sends = { fx_send("fx_crush", 0) } },
  { level = 5, name = "snr_smp",         group = "drums", sends = { key_feed("sc_snare") } },  -- triggers stay out of the crush (Drums page)
  { level = 4, name = "tom_bus",         group = "drums", sends = { fx_send("fx_snr_plate", TOM_PLATE_DB) } },
  { level = 5, name = "tom_1",           group = "drums", sends = { fx_send("fx_crush", 0) } },
  { level = 5, name = "tom_2",           group = "drums", sends = { fx_send("fx_crush", 0) } },
  { level = 5, name = "tom_flr",         group = "drums", sends = { fx_send("fx_crush", 0) } },
  { level = 4, name = "oh_cym_bus",      group = "drums" },
  { level = 5, name = "hh",              group = "drums" },
  { level = 5, name = "ride",            group = "drums" },
  { level = 5, name = "oh_fx_cym",       group = "drums" },
  { level = 5, name = "oh",              group = "drums" },
  { level = 4, name = "room_bus",        group = "drums" },  -- rooms carry cymbals: no crush
  { level = 5, name = "room_mono",       group = "drums" },
  { level = 5, name = "room_close",      group = "drums" },
  { level = 5, name = "room_far",        group = "drums" },
  -- GGD output map copied from the reference project. Insert GetGood Drums on this track.
  { level = 4, name = GGD_TRACK_NAME,    group = "drums", channels = 64, parent_send = false, sends = {
      ggd_out("kick_sum",   "1/2"),   ggd_out("kick_sub",  "3/4"),
      ggd_out("snr_top",    "5/6"),   ggd_out("snr_bot",   "7/8"),
      ggd_out("tom_1",      "9/10"),  ggd_out("tom_2",     "11/12"), ggd_out("tom_flr",   "13/14"),
      ggd_out("hh",         "15/16"), ggd_out("ride",      "17/18"), ggd_out("oh_fx_cym", "19/20"),
      ggd_out("kick_smp",   "21/22"), ggd_out("snr_smp",   "23/24"), ggd_out("oh",        "25/26"),
      ggd_out("room_mono",  "27/28"), ggd_out("room_close", "29/30"), ggd_out("room_far", "31/32"),
  } },

  { level = 3, name = "bass_bus",        group = "bass" },
  -- width 0 sums each band to mono after its plugins (backstop for the chanmix2 sum).
  { level = 4, name = "bass_low",        group = "bass", channels = 4, pan = 0, width = 0 },
  { level = 4, name = "bass_high",       group = "bass" },
  { level = 4, name = "bass_di",         group = "bass", parent_send = false, sends = {
      { to = "bass_low" }, { to = "bass_high" },
  } },

  -- Amp blend: both DIs play through amp A (folder) and, by post-fader send, amp B.
  -- Keys: sc_snare on 3/4, sc_spotlight on 5/6.
  { level = 3, name = "gtr_rhy_bus",     group = "guitars", channels = 6 },
  { level = 4, name = "gtr_rhy_amp_a",   group = "guitars" },  -- main stereo amp sim
  { level = 5, name = "gtr_rhy_l",       group = "guitars", pan = -1, width = 0, sends = { { to = "gtr_rhy_amp_b" } } },
  { level = 5, name = "gtr_rhy_r",       group = "guitars", pan = 1,  width = 0, sends = { { to = "gtr_rhy_amp_b" } } },
  { level = 4, name = "gtr_rhy_amp_b",   group = "guitars" },  -- clarity amp, blended under amp A
  { level = 3, name = "gtr_ld_bus",      group = "guitars", sends = {
      key_feed("sc_spotlight"), fx_send("fx_inst_plate"), fx_send("fx_inst_dly"),
  } },
  { level = 4, name = "gtr_ld",          group = "guitars" },
  { level = 4, name = "gtr_ld_harm",     group = "guitars" },
  { level = 3, name = "gtr_mel_bus",     group = "guitars", sends = { fx_send("fx_hall") } },
  { level = 4, name = "gtr_cln_l",       group = "guitars", pan = -0.35, width = 0 },
  { level = 4, name = "gtr_oct",         group = "guitars", pan = 0.35,  width = 0 },
  { level = 4, name = "gtr_amb",         group = "guitars" },

  { level = 3, name = "orch_syn_bus",    group = "orch", channels = 4 },
  { level = 4, name = "orch_str_vln",    group = "orch",  sends = { fx_send("fx_hall") } },
  { level = 4, name = "orch_str_vc",     group = "orch",  sends = { fx_send("fx_hall") } },
  { level = 4, name = "orch_brass",      group = "orch",  sends = { fx_send("fx_hall") } },
  { level = 4, name = "orch_choir",      group = "orch",  sends = { fx_send("fx_hall") } },
  { level = 4, name = "orch_perc",       group = "orch" },  -- no hall: hits clear before the next snare
  { level = 4, name = "syn_pad",         group = "synth", sends = { fx_send("fx_hall") } },
  { level = 4, name = "syn_ld",          group = "synth" },
  { level = 4, name = "syn_arp",         group = "synth", sends = { fx_send("fx_inst_dly") } },
  { level = 4, name = "syn_bass",        group = "synth", channels = 4 },
  { level = 4, name = "syn_sub",         group = "synth", channels = 4, pan = 0, width = 0 },
  { level = 4, name = "fx_hall",         group = "fx" },

  { level = 3, name = "sfx_bus",         group = "sfx" },
  { level = 4, name = "sfx_riser",       group = "sfx" },
  { level = 4, name = "sfx_impact",      group = "sfx" },
  { level = 4, name = "sfx_sweep",       group = "sfx" },
  { level = 4, name = "sfx_rev",         group = "sfx" },
  { level = 4, name = "sfx_subdrop",     group = "sfx", channels = 4 },
  -- Copies of fx_vox_plate and fx_vox_dly, so no instrument tail lands in vocal_master.
  { level = 3, name = "fx_inst_plate",   group = "fx", channels = 4 },
  { level = 3, name = "fx_inst_dly",     group = "fx", channels = 4 },

  -- Every vocal send lands inside this folder, so muting it leaves no vocal tails.
  { level = 2, name = "vocal_master",    group = "white" },
  { level = 3, name = "vox_ld_bus",      group = "vocals", sends = {
      fx_send("fx_vox_plate"), fx_send("fx_vox_slap"),
      fx_send("fx_vox_dly", SILENT_DB),  -- automated throws
  } },
  -- Only the lead and the main scream key the spotlight, so doubles never deepen the duck.
  { level = 4, name = "vox_ld",          group = "vocals", sends = { key_feed("sc_spotlight") } },
  { level = 4, name = "vox_scrm",        group = "vocals", sends = { key_feed("sc_spotlight") } },
  -- Doubles sum into vox_ld_bus: they share its effects and stay inside vocal_master.
  { level = 4, name = "vox_ld_dbl_bus",  group = "vocals" },
  { level = 5, name = "vox_ld_dbl_l",    group = "vocals", pan = -1, width = 0 },
  { level = 5, name = "vox_ld_dbl_r",    group = "vocals", pan = 1,  width = 0 },
  { level = 4, name = "vox_scrm_dbl_bus", group = "vocals" },  -- own glue compressor
  { level = 5, name = "vox_scrm_dbl_l",  group = "vocals", pan = -1, width = 0 },
  { level = 5, name = "vox_scrm_dbl_r",  group = "vocals", pan = 1,  width = 0 },
  { level = 3, name = "vox_bgv_bus",     group = "vocals", sends = { fx_send("fx_vox_plate"), fx_send("fx_vox_hall") } },
  { level = 4, name = "vox_harm_hi",     group = "vocals", pan = -0.85, width = 0 },
  { level = 4, name = "vox_harm_lo",     group = "vocals", pan = 0.85,  width = 0 },
  { level = 4, name = "vox_bgv_l",       group = "vocals", pan = -0.9,  width = 0 },
  { level = 4, name = "vox_bgv_r",       group = "vocals", pan = 0.9,   width = 0 },
  { level = 4, name = "vox_gang",        group = "vocals" },
  { level = 4, name = "vox_adlib",       group = "vocals" },
  { level = 3, name = "fx_vox_plate",    group = "fx", channels = 4 },
  { level = 3, name = "fx_vox_slap",     group = "fx" },
  { level = 3, name = "fx_vox_dly",      group = "fx", channels = 4 },
  { level = 3, name = "fx_vox_hall",     group = "fx", channels = 4 },

  -- Silent sidechain hubs: outside master_bus, never reach the master.
  { level = 0, name = "sc_kick",         group = "hub", parent_send = false, sends = {
      key_out("bass_low"), key_out("syn_sub"), key_out("sfx_subdrop"), key_out("syn_bass"),
  } },
  { level = 0, name = "sc_snare",        group = "hub", parent_send = false, sends = {
      key_out("gtr_rhy_bus"), key_out("orch_syn_bus"),
  } },
  { level = 0, name = "sc_spotlight",    group = "hub", parent_send = false, sends = {
      key_out("instrument_bus"), key_out("fx_inst_plate"), key_out("fx_inst_dly"),
      key_out("fx_vox_plate"), key_out("fx_vox_dly"), key_out("fx_vox_hall"),
      key_out("gtr_rhy_bus", "5/6"),  -- 3/4 already carries the sc_snare key
  } },
}

-- REAPER visual spacer (TCP gap) above each listed track. Sections, then subsections.
local SPACER_ABOVE = {
  -- sections
  "bass_bus", "gtr_rhy_bus", "orch_syn_bus", "sfx_bus", "fx_inst_plate", "vocal_master", "sc_kick",
  -- drum subsections
  "kick_bus", "snr_bus", "tom_bus", "oh_cym_bus", "room_bus", GGD_TRACK_NAME,
  -- bass, guitar, orch/synth and vocal subsections
  "bass_high", "bass_di", "gtr_rhy_amp_b", "gtr_ld_bus", "gtr_mel_bus", "syn_pad", "fx_hall", "vox_ld_dbl_bus",
  "vox_bgv_bus", "fx_vox_plate",
}

--------------------------------------------------------------------------------
-- BUILDER. No edits needed below.
--------------------------------------------------------------------------------

local UPDATE_UNDO_LABEL = "WAP: update mix template"
local SEND_MODE = { post = 0, prefx = 1, pre = 3 }
local SEND_MODE_NAME = { [0] = "post-fader", [1] = "pre-FX", [3] = "pre-fader" }
local CATEGORY_SEND = 0
local MB_OK, MB_YESNOCANCEL, MB_YESNO = 0, 3, 4
local ANSWER_CANCEL, ANSWER_YES, ANSWER_NO = 2, 6, 7
local CUSTOM_COLOR_FLAG = 0x1000000
local MONO_FLAG = 1024
local CHANNEL_COUNT_SHIFT = 1024
local MIDI_SEND_DISABLED = 31
local STEREO_TO_PARENT = 2
local SPACER_ON, SPACER_OFF = 1, 0  -- I_SPACER: 1 = TCP track spacer above this track (ReaScript API, REAPER 7.86)
local PANMODE_STEREO = 5
local PANMODE_NAME = { [-1] = "project default", [0] = "classic", [3] = "balance", [5] = "stereo pan", [6] = "dual pan" }
local TOLERANCE = 1e-6
local REPORT_NAME_LIMIT = 20

local function parse_channels(spec)
  local first, second = spec:match("^(%d+)/(%d+)$")
  if first then
    first, second = tonumber(first), tonumber(second)
    if second ~= first + 1 then return nil end
    return first - 1, 2
  end
  local lone = spec:match("^(%d+)$")
  if lone then return tonumber(lone) - 1, 1 end
  local low, high = spec:match("^(%d+)%-(%d+)$")
  if low then
    local count = tonumber(high) - tonumber(low) + 1
    if count < 4 or count % 2 ~= 0 then return nil end
    return tonumber(low) - 1, count
  end
  return nil
end

-- I_SRCCHAN: low 10 bits = first channel; (value >> 10) is 0 stereo, 1 mono, N/2 for N channels.
local function encode_src_channels(spec)
  local offset, count = parse_channels(spec)
  if count == 1 then return offset | MONO_FLAG end
  if count == 2 then return offset end
  return offset + CHANNEL_COUNT_SHIFT * (count // 2)
end

-- I_DSTCHAN: low 10 bits = first destination channel.
local function encode_dst_channels(spec)
  local offset = parse_channels(spec)
  return offset
end

local function db_to_gain(db)
  if db == SILENT_DB then return 0 end
  return 10 ^ (db / 20)
end

local function is_close(a, b) return math.abs(a - b) <= TOLERANCE end

local function with_defaults(entry)
  local sends = {}
  for _, send in ipairs(entry.sends or {}) do
    sends[#sends + 1] = {
      to = send.to,
      mode = send.mode or "post",
      db = send.db or 0,
      src = send.src or "1/2",
      dst = send.dst or "1/2",
    }
  end
  return {
    level = entry.level,
    name = entry.name,
    group = entry.group,
    channels = entry.channels or 2,
    parent_send = entry.parent_send ~= false,
    pan = entry.pan or 0,
    width = entry.width,
    volume_db = entry.volume_db,
    sends = sends,
  }
end

local function folder_depth_changes(tracks)
  local changes = {}
  for i, track in ipairs(tracks) do
    local next_level = tracks[i + 1] and tracks[i + 1].level or 0
    changes[i] = next_level - track.level
  end
  return changes
end

local function last_channel(spec)
  local offset, count = parse_channels(spec)
  return offset + count
end

local function validate(tracks)
  local errors, by_name = {}, {}
  local function fail(msg) errors[#errors + 1] = msg end
  for i, track in ipairs(tracks) do
    local previous_level = i > 1 and tracks[i - 1].level or 0
    if by_name[track.name] then fail("duplicate name: " .. track.name) end
    by_name[track.name] = track
    if not GROUP_COLORS[track.group] then fail(track.name .. ": unknown color group " .. tostring(track.group)) end
    if track.level < 0 or track.level > previous_level + 1 then fail(track.name .. ": level jumps more than 1") end
    if track.channels < 2 or track.channels > 128 or track.channels % 2 ~= 0 then
      fail(track.name .. ": channels must be even, 2-128")
    end
    if track.pan < -1 or track.pan > 1 then fail(track.name .. ": pan must be -1..1") end
    if track.width and (track.width < -1 or track.width > 1) then fail(track.name .. ": width must be -1..1") end
  end
  if tracks[1] and tracks[1].level ~= 0 then fail("first track must be level 0") end
  for _, name in ipairs(SPACER_ABOVE) do
    if not by_name[name] then fail("SPACER_ABOVE: " .. name .. " not in TEMPLATE") end
  end
  for _, track in ipairs(tracks) do
    for _, send in ipairs(track.sends) do
      local dest = by_name[send.to]
      local label = track.name .. " -> " .. tostring(send.to)
      if not dest then fail(label .. ": destination not in TEMPLATE")
      elseif not SEND_MODE[send.mode] then fail(label .. ": unknown mode " .. tostring(send.mode))
      elseif not parse_channels(send.src) or not parse_channels(send.dst) then fail(label .. ": bad channel spec")
      elseif last_channel(send.src) > track.channels then fail(label .. ": src beyond source channels")
      elseif last_channel(send.dst) > dest.channels then fail(label .. ": dst beyond destination channels")
      end
    end
  end
  return errors
end

local function open_folder_depth()
  local depth = 0
  for i = 0, reaper.CountTracks(0) - 1 do
    depth = depth + reaper.GetMediaTrackInfo_Value(reaper.GetTrack(0, i), "I_FOLDERDEPTH")
  end
  return depth
end

local function close_open_folders(depth)
  local last = reaper.GetTrack(0, reaper.CountTracks(0) - 1)
  local current = reaper.GetMediaTrackInfo_Value(last, "I_FOLDERDEPTH")
  reaper.SetMediaTrackInfo_Value(last, "I_FOLDERDEPTH", current - depth)
end

local function native_color(group, is_folder)
  local shades = GROUP_COLORS[group]
  local hex = is_folder and shades.bus or shades.track
  local red, green, blue = (hex >> 16) & 0xff, (hex >> 8) & 0xff, hex & 0xff
  return reaper.ColorToNative(red, green, blue) | CUSTOM_COLOR_FLAG
end

-- The track properties the template owns, in the order they must be set.
local function template_properties(track, is_folder, has_spacer)
  local properties = {}
  local function add(key, value) properties[#properties + 1] = { key = key, value = value } end
  add("I_NCHAN", track.channels)
  add("B_MAINSEND", track.parent_send and 1 or 0)
  if track.parent_send and track.channels > STEREO_TO_PARENT then
    add("C_MAINSEND_NCH", STEREO_TO_PARENT)  -- keeps sidechain keys out of the parent bus
  end
  add("I_CUSTOMCOLOR", native_color(track.group, is_folder))
  add("I_SPACER", has_spacer and SPACER_ON or SPACER_OFF)
  if track.width then add("I_PANMODE", PANMODE_STEREO) end
  add("D_PAN", track.pan)
  if track.width then add("D_WIDTH", track.width) end
  if track.volume_db then add("D_VOL", db_to_gain(track.volume_db)) end
  return properties
end

-- Adds parent, folder depth, earlier siblings and properties to each template track.
local function plan_template(tracks)
  local depth_changes = folder_depth_changes(tracks)
  local spacer_above, ancestors = {}, {}
  for _, name in ipairs(SPACER_ABOVE) do spacer_above[name] = true end
  for i, track in ipairs(tracks) do
    for level = #ancestors, track.level + 1, -1 do ancestors[level] = nil end
    track.parent = ancestors[track.level]
    track.depth_change = depth_changes[i]
    track.properties = template_properties(track, depth_changes[i] > 0, spacer_above[track.name])
    track.siblings_before = {}
    for j = i - 1, 1, -1 do
      if tracks[j].level < track.level then break end
      if tracks[j].level == track.level then track.siblings_before[#track.siblings_before + 1] = tracks[j] end
    end
    ancestors[track.level + 1] = track
  end
end

local function apply_properties(handle, properties)
  for _, property in ipairs(properties) do
    reaper.SetMediaTrackInfo_Value(handle, property.key, property.value)
  end
end

local function send_settings(send)
  return {
    { key = "I_SENDMODE", value = SEND_MODE[send.mode] },
    { key = "D_VOL", value = db_to_gain(send.db) },
    { key = "I_SRCCHAN", value = encode_src_channels(send.src) },
    { key = "I_DSTCHAN", value = encode_dst_channels(send.dst) },
    { key = "I_MIDIFLAGS", value = MIDI_SEND_DISABLED },
  }
end

local function add_send(source, dest, send)
  local send_index = reaper.CreateTrackSend(source, dest)
  if send_index < 0 then return false end
  for _, setting in ipairs(send_settings(send)) do
    reaper.SetTrackSendInfo_Value(source, CATEGORY_SEND, send_index, setting.key, setting.value)
  end
  return true
end

local function create_tracks(tracks, first_index)
  local handles = {}
  for i, track in ipairs(tracks) do
    local index = first_index + i - 1
    reaper.InsertTrackAtIndex(index, false)
    local handle = reaper.GetTrack(0, index)
    reaper.GetSetMediaTrackInfo_String(handle, "P_NAME", track.name, true)
    apply_properties(handle, track.properties)
    reaper.SetMediaTrackInfo_Value(handle, "I_FOLDERDEPTH", track.depth_change)
    handles[track.name] = handle
  end
  return handles
end

local function create_sends(tracks, handles)
  local created = 0
  for _, track in ipairs(tracks) do
    for _, send in ipairs(track.sends) do
      if add_send(handles[track.name], handles[send.to], send) then created = created + 1 end
    end
  end
  return created
end

--------------------------------------------------------------------------------
-- UPDATE MODE: bring a project built from an older template in line, in place.
--------------------------------------------------------------------------------

local function track_name(handle)
  local _, name = reaper.GetSetMediaTrackInfo_String(handle, "P_NAME", "", false)
  return name
end

local function gain_text(gain)
  if gain <= 0 then return "-inf dB" end
  return string.format("%.1f dB", 20 * math.log(gain, 10))
end

local function pan_text(pan)
  if is_close(pan, 0) then return "center" end
  return string.format("%d%% %s", math.floor(math.abs(pan) * 100 + 0.5), pan < 0 and "L" or "R")
end

local function color_text(native)
  native = math.floor(native)
  if native & CUSTOM_COLOR_FLAG == 0 then return "default" end
  local red, green, blue = reaper.ColorFromNative(native & 0xffffff)
  return string.format("#%02X%02X%02X", red, green, blue)
end

local function channels_text(count)
  if count == 0 then return "all" end
  return string.format("%d ch", math.floor(count))
end

local function on_off_text(value) return value ~= 0 and "on" or "off" end

local FIELDS = {
  I_NCHAN        = { label = "track channels",     text = channels_text },
  B_MAINSEND     = { label = "parent send",        text = on_off_text },
  C_MAINSEND_NCH = { label = "channels to parent", text = channels_text },
  I_CUSTOMCOLOR  = { label = "color",              text = color_text },
  I_SPACER       = { label = "spacer above",       text = on_off_text },
  I_PANMODE      = { label = "pan mode",           text = function(v) return PANMODE_NAME[math.floor(v)] or tostring(v) end },
  D_PAN          = { label = "pan",                text = pan_text },
  D_WIDTH        = { label = "width",              text = function(v) return string.format("%d%%", math.floor(v * 100 + 0.5)) end },
  D_VOL          = { label = "volume",             text = gain_text },
}

local function send_label(send) return string.format("send to %s (%s -> %s)", send.to, send.src, send.dst) end
local function send_text(send) return SEND_MODE_NAME[SEND_MODE[send.mode]] .. ", " .. gain_text(db_to_gain(send.db)) end

-- Every project track with its name and folder parent, in track order.
local function scan_project()
  local list, open_folders = {}, {}
  for i = 0, reaper.CountTracks(0) - 1 do
    local handle = reaper.GetTrack(0, i)
    local entry = { handle = handle, name = track_name(handle), parent = open_folders[#open_folders] }
    list[#list + 1] = entry
    local depth = reaper.GetMediaTrackInfo_Value(handle, "I_FOLDERDEPTH")
    if depth > 0 then open_folders[#open_folders + 1] = entry end
    for _ = 1, -depth do open_folders[#open_folders] = nil end
  end
  return list
end

-- handles: template name -> its one project track. ambiguous: template names used more than once.
local function match_template(tracks, project)
  local count, entry_of = {}, {}
  for _, entry in ipairs(project) do
    count[entry.name] = (count[entry.name] or 0) + 1
    entry_of[entry.name] = entry
  end
  local handles, entries, ambiguous = {}, {}, {}
  for _, track in ipairs(tracks) do
    if count[track.name] == 1 then
      handles[track.name] = entry_of[track.name].handle
      entries[track.name] = entry_of[track.name]
    elseif count[track.name] then
      ambiguous[track.name] = true
    end
  end
  return handles, entries, ambiguous
end

local function project_sends(handle)
  local sends = {}
  for i = 0, reaper.GetTrackNumSends(handle, CATEGORY_SEND) - 1 do
    local function get(key) return reaper.GetTrackSendInfo_Value(handle, CATEGORY_SEND, i, key) end
    sends[#sends + 1] = { index = i, dest = get("P_DESTTRACK"), src = get("I_SRCCHAN"), dst = get("I_DSTCHAN"),
      mode = get("I_SENDMODE"), gain = get("D_VOL") }
  end
  return sends
end

-- A template send matches a project send on destination, source channels and destination channels.
local function find_send(existing, dest, send)
  local src, dst = encode_src_channels(send.src), encode_dst_channels(send.dst)
  for _, candidate in ipairs(existing) do
    if candidate.dest == dest and is_close(candidate.src, src) and is_close(candidate.dst, dst) then return candidate end
  end
end

-- Folder level and depth of every project track (0-based), from the cumulative I_FOLDERDEPTH.
local function folder_levels()
  local levels, depths, level = {}, {}, 0
  for i = 0, reaper.CountTracks(0) - 1 do
    levels[i] = level
    depths[i] = reaper.GetMediaTrackInfo_Value(reaper.GetTrack(0, i), "I_FOLDERDEPTH")
    level = level + depths[i]
  end
  return levels, depths
end

local function track_index(handle)
  for i = 0, reaper.CountTracks(0) - 1 do
    if reaper.GetTrack(0, i) == handle then return i end
  end
end

local function last_descendant_index(index, levels)
  local last = index
  while levels[last + 1] and levels[last + 1] > levels[index] do last = last + 1 end
  return last
end

-- The new track goes after the last descendant of its nearest existing earlier sibling,
-- else directly after its parent. Returns the anchor index (nil = top of project) and the level.
local function insertion_point(track, handles, levels)
  for _, sibling in ipairs(track.siblings_before) do
    local handle = handles[sibling.name]
    if handle then
      local index = track_index(handle)
      return last_descendant_index(index, levels), levels[index]
    end
  end
  if track.parent then
    local index = track_index(handles[track.parent.name])
    return index, levels[index] + 1
  end
  return nil, 0
end

-- Only the anchor's folder depth changes, so every existing track keeps its parent.
local function insert_template_track(track, handles)
  local levels, depths = folder_levels()
  local anchor, level = insertion_point(track, handles, levels)
  local index = anchor and anchor + 1 or 0
  reaper.InsertTrackAtIndex(index, false)
  local handle = reaper.GetTrack(0, index)
  if anchor then
    reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, anchor), "I_FOLDERDEPTH", level - levels[anchor])
    reaper.SetMediaTrackInfo_Value(handle, "I_FOLDERDEPTH", levels[anchor] + depths[anchor] - level)
  else
    reaper.SetMediaTrackInfo_Value(handle, "I_FOLDERDEPTH", 0)
  end
  reaper.GetSetMediaTrackInfo_String(handle, "P_NAME", track.name, true)
  apply_properties(handle, track.properties)
  handles[track.name] = handle
end

local function property_differences(track, handle)
  local diffs = {}
  for _, property in ipairs(track.properties) do
    local current = reaper.GetMediaTrackInfo_Value(handle, property.key)
    if not is_close(current, property.value) then
      local field = FIELDS[property.key]
      diffs[#diffs + 1] = { track = track.name, change = field.label, now = field.text(current),
        want = field.text(property.value),
        apply = function() reaper.SetMediaTrackInfo_Value(handle, property.key, property.value) end }
    end
  end
  return diffs
end

local function send_setting_differences(track, handle, match, send)
  local diffs = {}
  local function compare(key, label, current, wanted, text)
    if not is_close(current, wanted) then
      diffs[#diffs + 1] = { track = track.name, change = send_label(send) .. " " .. label, now = text(current),
        want = text(wanted),
        apply = function() reaper.SetTrackSendInfo_Value(handle, CATEGORY_SEND, match.index, key, wanted) end }
    end
  end
  compare("I_SENDMODE", "mode", match.mode, SEND_MODE[send.mode], function(v) return SEND_MODE_NAME[math.floor(v)] or tostring(v) end)
  compare("D_VOL", "level", match.gain, db_to_gain(send.db), gain_text)
  return diffs
end

local function present(...)
  local list = {}
  for _, item in pairs({ ... }) do list[#list + 1] = item end
  return list
end

-- Lists every difference in apply order: track inserts and properties, then sends.
-- A diff with `requires` runs only when those diffs are approved. An `auto` diff is never prompted.
local function collect_differences(tracks, handles, ambiguous)
  local diffs, skipped, inserts = {}, {}, {}
  local function add(diff) diffs[#diffs + 1] = diff end
  local function skip(name, change, reason) skipped[#skipped + 1] = { track = name, change = change, reason = reason } end

  for _, track in ipairs(tracks) do
    local parent = track.parent
    if handles[track.name] then
      for _, diff in ipairs(property_differences(track, handles[track.name])) do add(diff) end
    elseif ambiguous[track.name] then
      -- left alone; listed in the report
    elseif parent and not handles[parent.name] and not inserts[parent.name] then
      skip(track.name, "insert track", "parent " .. parent.name .. " is ambiguous or not inserted")
    else
      local diff = { track = track.name, change = "insert track", now = "missing", is_insert = true,
        want = string.format("insert at level %d under %s", track.level, parent and parent.name or "the top level"),
        requires = present(parent and inserts[parent.name]), blocked = "parent not inserted",
        apply = function() insert_template_track(track, handles) end }
      inserts[track.name] = diff
      add(diff)
    end
  end

  for _, track in ipairs(tracks) do
    local source, source_insert = handles[track.name], inserts[track.name]
    if source or source_insert then
      local existing = source and project_sends(source) or {}
      for _, send in ipairs(track.sends) do
        local dest_insert = inserts[send.to]
        local match = source and handles[send.to] and find_send(existing, handles[send.to], send)
        if not handles[send.to] and not dest_insert then
          skip(track.name, send_label(send), "destination is ambiguous or not inserted")
        elseif match then
          for _, diff in ipairs(send_setting_differences(track, source, match, send)) do add(diff) end
        else
          -- A new track's own sends follow its insert without a prompt.
          add({ track = track.name, change = "add " .. send_label(send), now = "none", want = send_text(send),
            auto = source_insert ~= nil, requires = present(source_insert, dest_insert), blocked = "track not inserted",
            apply = function() add_send(handles[track.name], handles[send.to], send) end })
        end
      end
    end
  end
  return diffs, skipped
end

local function requirements_met(diff)
  for _, needed in ipairs(diff.requires or {}) do
    if not needed.approved then return false end
  end
  return true
end

local function review_prompt(diff, position, total)
  return string.format("Difference %d of %d\n\nTrack: %s\nChange: %s\nNow: %s\nTemplate: %s\n\n" ..
    "Yes = apply. No = skip. Cancel = stop reviewing.", position, total, diff.track, diff.change, diff.now, diff.want)
end

local function approved_count(diffs)
  local count = 0
  for _, diff in ipairs(diffs) do
    if diff.approved and not diff.auto then count = count + 1 end
  end
  return count
end

-- Marks each diff approved or skipped. Returns true when the approved diffs should be applied.
local function decide(diffs, total, missing)
  local answer = reaper.MB(string.format(
    "Found %d differences (%d missing tracks).\n\nYes = apply all. No = review each. Cancel = stop.", total, missing),
    UPDATE_UNDO_LABEL, MB_YESNOCANCEL)
  if answer ~= ANSWER_YES and answer ~= ANSWER_NO then return false end
  local reviewing, stopped, position = answer == ANSWER_NO, false, 0
  for _, diff in ipairs(diffs) do
    if not requirements_met(diff) then
      diff.skip_reason = diff.blocked
    elseif diff.auto or not reviewing then
      diff.approved = true
    elseif stopped then
      diff.skip_reason = "not reviewed"
    else
      position = position + 1
      local reply = reaper.MB(review_prompt(diff, position, total), UPDATE_UNDO_LABEL, MB_YESNOCANCEL)
      if reply == ANSWER_YES then
        diff.approved = true
      elseif reply == ANSWER_NO then
        diff.skip_reason = "declined"
      else
        stopped, diff.skip_reason = true, "not reviewed"
      end
    end
  end
  local count = approved_count(diffs)
  if count == 0 then return false end
  if not stopped then return true end
  return reaper.MB(string.format("Apply the %d changes approved so far?", count), UPDATE_UNDO_LABEL, MB_YESNO) == ANSWER_YES
end

local function apply_approved(diffs)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  for _, diff in ipairs(diffs) do
    if diff.approved then diff.apply() end
  end
  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock(UPDATE_UNDO_LABEL, -1)
end

-- Report-only findings: tracks in another folder than the template says, and project extras.
local function project_notes(tracks, project, entries)
  local notes = { parents = {}, extra_tracks = {}, extra_sends = {} }
  local in_template = {}
  for _, track in ipairs(tracks) do in_template[track.name] = true end
  for _, track in ipairs(tracks) do
    local entry = entries[track.name]
    if entry then
      local now = entry.parent and entry.parent.name or "the top level"
      local want = track.parent and track.parent.name or "the top level"
      if now ~= want then
        notes.parents[#notes.parents + 1] = string.format("%s: in %s, template puts it in %s", track.name, now, want)
      end
      for _, existing in ipairs(project_sends(entry.handle)) do
        local known = false
        for _, send in ipairs(track.sends) do
          if find_send({ existing }, entries[send.to] and entries[send.to].handle, send) then known = true end
        end
        if not known then
          notes.extra_sends[#notes.extra_sends + 1] = track.name .. " -> " .. track_name(existing.dest)
        end
      end
    end
  end
  for _, entry in ipairs(project) do
    if not in_template[entry.name] then notes.extra_tracks[#notes.extra_tracks + 1] = entry.name end
  end
  return notes
end

local function print_list(title, lines)
  if #lines == 0 then return end
  reaper.ShowConsoleMsg(string.format("%s: %d\n", title, #lines))
  for i = 1, math.min(#lines, REPORT_NAME_LIMIT) do reaper.ShowConsoleMsg("  " .. lines[i] .. "\n") end
  if #lines > REPORT_NAME_LIMIT then reaper.ShowConsoleMsg(string.format("  ... and %d more\n", #lines - REPORT_NAME_LIMIT)) end
end

local function report_update(diffs, skipped, ambiguous, notes)
  local applied_lines, skipped_lines, ambiguous_names = {}, {}, {}
  for _, diff in ipairs(diffs) do
    if diff.approved then
      applied_lines[#applied_lines + 1] = string.format("%s: %s: %s -> %s", diff.track, diff.change, diff.now, diff.want)
    else
      skipped_lines[#skipped_lines + 1] = string.format("%s: %s (%s)", diff.track, diff.change, diff.skip_reason)
    end
  end
  for _, item in ipairs(skipped) do
    skipped_lines[#skipped_lines + 1] = string.format("%s: %s (%s)", item.track, item.change, item.reason)
  end
  for name in pairs(ambiguous) do ambiguous_names[#ambiguous_names + 1] = name end
  table.sort(ambiguous_names)
  reaper.ShowConsoleMsg(UPDATE_UNDO_LABEL .. "\n")
  reaper.ShowConsoleMsg(string.format("Applied: %d\n", #applied_lines))
  for _, line in ipairs(applied_lines) do reaper.ShowConsoleMsg("  " .. line .. "\n") end
  print_list("Skipped", skipped_lines)
  print_list("Ambiguous (name used more than once; left alone)", ambiguous_names)
  print_list("Parent differs from the template (not changed; move by hand if wanted)", notes.parents)
  print_list("Tracks not in the template (left alone)", notes.extra_tracks)
  print_list("Sends not in the template (left alone)", notes.extra_sends)
end

local function update_project(tracks)
  local project = scan_project()
  local handles, entries, ambiguous = match_template(tracks, project)
  local notes = project_notes(tracks, project, entries)
  local diffs, skipped = collect_differences(tracks, handles, ambiguous)
  local total, missing = 0, 0
  for _, diff in ipairs(diffs) do
    if not diff.auto then total = total + 1 end
    if diff.is_insert then missing = missing + 1 end
  end
  if total == 0 then
    reaper.MB("The project already matches the template. Nothing was changed.", UPDATE_UNDO_LABEL, MB_OK)
    report_update(diffs, skipped, ambiguous, notes)
    return
  end
  if not decide(diffs, total, missing) then
    reaper.ShowConsoleMsg(UPDATE_UNDO_LABEL .. ": stopped. Nothing was changed.\n")
    return
  end
  apply_approved(diffs)
  report_update(diffs, skipped, ambiguous, notes)
end

local function project_has_template_tracks(tracks)
  local names = {}
  for _, track in ipairs(tracks) do names[track.name] = true end
  for i = 0, reaper.CountTracks(0) - 1 do
    if names[track_name(reaper.GetTrack(0, i))] then return true end
  end
  return false
end

local function user_confirms_append(existing_count)
  local message = string.format(
    "This project already has %d tracks.\n\nYes = add the WAP template after them.\nNo = cancel.\n\nExisting tracks are never deleted.",
    existing_count)
  return reaper.MB(message, UNDO_LABEL, MB_YESNO) == ANSWER_YES
end

local function report(track_count, send_count, closed_folders)
  reaper.ShowConsoleMsg(UNDO_LABEL .. "\n")
  reaper.ShowConsoleMsg(string.format("Tracks created: %d\n", track_count))
  reaper.ShowConsoleMsg(string.format("Sends created: %d\n", send_count))
  if closed_folders > 0 then
    reaper.ShowConsoleMsg(string.format("Closed %d open folder level(s) on the last existing track.\n", closed_folders))
  end
  reaper.ShowConsoleMsg("NEXT: insert GetGood Drums (Kontakt, 64 out) on track '" .. GGD_TRACK_NAME ..
    "'. Its 16 stereo outputs already feed the kit tracks.\n")
  reaper.ShowConsoleMsg("No plugins were added. Hub keys arrive on channels 3/4 (sc_spotlight on gtr_rhy_bus: 5/6): " ..
    "point each detector at Auxiliary Input.\n")
end

local function build_template(tracks, existing_count)
  reaper.Undo_BeginBlock()
  reaper.PreventUIRefresh(1)
  local open_depth = 0
  if existing_count > 0 then
    open_depth = math.max(0, math.floor(open_folder_depth()))
    if open_depth > 0 then close_open_folders(open_depth) end
  end
  local handles = create_tracks(tracks, existing_count)
  local send_count = create_sends(tracks, handles)
  reaper.PreventUIRefresh(-1)
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  reaper.Undo_EndBlock(UNDO_LABEL, -1)

  report(#tracks, send_count, open_depth)
end

local function main()
  local tracks = {}
  for i, entry in ipairs(TEMPLATE) do tracks[i] = with_defaults(entry) end

  local errors = validate(tracks)
  if #errors > 0 then
    reaper.MB("TEMPLATE has errors. Nothing was changed.\n\n" .. table.concat(errors, "\n"), UNDO_LABEL, MB_OK)
    return
  end
  plan_template(tracks)

  local existing_count = reaper.CountTracks(0)
  if existing_count == 0 then
    build_template(tracks, 0)
  elseif project_has_template_tracks(tracks) then
    update_project(tracks)
  elseif user_confirms_append(existing_count) then
    build_template(tracks, existing_count)
  end
end

main()
