-- @description WAP: build mix template (tracks, folders, routing, names, colors; no plugins)
-- @version 1.0
-- @about Builds the WAP Mix Console template in the current project. Pure REAPER API. Edit the TEMPLATE table to change the layout.

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
--   sends        list of { to, mode, db, src, dst }
--                  to    destination track name
--                  mode  "post" (post-fader), "pre" (pre-fader, post-FX), "prefx"
--                  db    send level in dB (default 0)
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

local function ggd_out(to, src) return { to = to, mode = "pre", db = GGD_OUT_DB, src = src } end
local function key_feed(hub) return { to = hub, mode = "pre", db = 0 } end
local function key_out(target) return { to = target, mode = "pre", db = 0, dst = "3/4" } end
local function fx_send(ret, db) return { to = ret, mode = "post", db = db or FX_SEND_DB } end

local TEMPLATE = {
  -- The mastering chain lives here. REAPER's master track stays empty at unity.
  { level = 0, name = "master_bus",      group = "white" },
  { level = 1, name = "print_bus",       group = "white" },
  { level = 2, name = "instrument_bus",  group = "white", channels = 4 },

  { level = 3, name = "drum_bus",        group = "drums" },
  { level = 4, name = "fx_crush",        group = "fx" },
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
  { level = 4, name = "bass_low",        group = "bass", channels = 4 },
  { level = 4, name = "bass_high",       group = "bass" },
  { level = 5, name = "bass_amp",        group = "bass" },
  { level = 5, name = "bass_grit",       group = "bass" },
  { level = 4, name = "bass_di",         group = "bass", parent_send = false, sends = {
      { to = "bass_low" }, { to = "bass_high" },
  } },

  { level = 3, name = "gtr_rhy_bus",     group = "guitars", channels = 4 },
  { level = 4, name = "gtr_rhy_l",       group = "guitars" },
  { level = 4, name = "gtr_rhy_r",       group = "guitars" },
  { level = 4, name = "gtr_rhy_l2",      group = "guitars" },
  { level = 4, name = "gtr_rhy_r2",      group = "guitars" },
  { level = 3, name = "gtr_ld_bus",      group = "guitars", sends = {
      key_feed("sc_spotlight"), fx_send("fx_inst_plate"), fx_send("fx_inst_dly"),
  } },
  { level = 4, name = "gtr_ld",          group = "guitars" },
  { level = 4, name = "gtr_ld_harm",     group = "guitars" },
  { level = 3, name = "gtr_mel_bus",     group = "guitars", sends = { fx_send("fx_hall") } },
  { level = 4, name = "gtr_cln_l",       group = "guitars" },
  { level = 4, name = "gtr_oct",         group = "guitars" },
  { level = 4, name = "gtr_amb",         group = "guitars" },

  { level = 3, name = "orch_syn_bus",    group = "orch", channels = 4 },
  { level = 4, name = "orch_str_vln",    group = "orch",  sends = { fx_send("fx_hall") } },
  { level = 4, name = "orch_str_vc",     group = "orch",  sends = { fx_send("fx_hall") } },
  { level = 4, name = "orch_brass",      group = "orch",  sends = { fx_send("fx_hall") } },
  { level = 4, name = "orch_choir",      group = "orch",  sends = { fx_send("fx_hall") } },
  { level = 4, name = "orch_perc",       group = "orch",  sends = { fx_send("fx_hall") } },
  { level = 4, name = "syn_pad",         group = "synth", sends = { fx_send("fx_hall") } },
  { level = 4, name = "syn_ld",          group = "synth" },
  { level = 4, name = "syn_arp",         group = "synth", sends = { fx_send("fx_inst_dly") } },
  { level = 4, name = "syn_bass",        group = "synth" },
  { level = 4, name = "syn_sub",         group = "synth", channels = 4 },
  { level = 4, name = "fx_hall",         group = "fx" },

  { level = 3, name = "sfx_bus",         group = "sfx" },
  { level = 4, name = "sfx_riser",       group = "sfx" },
  { level = 4, name = "sfx_impact",      group = "sfx" },
  { level = 4, name = "sfx_sweep",       group = "sfx" },
  { level = 4, name = "sfx_rev",         group = "sfx" },
  { level = 4, name = "sfx_subdrop",     group = "sfx" },
  -- Copies of fx_vox_plate and fx_vox_dly, so no instrument tail lands in vocal_master.
  { level = 3, name = "fx_inst_plate",   group = "fx", channels = 4 },
  { level = 3, name = "fx_inst_dly",     group = "fx", channels = 4 },

  -- Every vocal send lands inside this folder, so muting it leaves no vocal tails.
  { level = 2, name = "vocal_master",    group = "white" },
  { level = 3, name = "vox_ld_bus",      group = "vocals", sends = {
      key_feed("sc_spotlight"), fx_send("fx_vox_plate"), fx_send("fx_vox_slap"), fx_send("fx_vox_dly"),
  } },
  { level = 4, name = "vox_ld",          group = "vocals" },
  { level = 4, name = "vox_scrm",        group = "vocals" },
  { level = 3, name = "vox_bgv_bus",     group = "vocals", sends = { fx_send("fx_vox_plate"), fx_send("fx_vox_hall") } },
  { level = 4, name = "vox_dbl_l",       group = "vocals" },
  { level = 4, name = "vox_dbl_r",       group = "vocals" },
  { level = 4, name = "vox_harm_hi",     group = "vocals" },
  { level = 4, name = "vox_harm_lo",     group = "vocals" },
  { level = 4, name = "vox_bgv_l",       group = "vocals" },
  { level = 4, name = "vox_bgv_r",       group = "vocals" },
  { level = 4, name = "vox_gang",        group = "vocals" },
  { level = 4, name = "vox_adlib",       group = "vocals" },
  { level = 3, name = "fx_vox_plate",    group = "fx", channels = 4 },
  { level = 3, name = "fx_vox_slap",     group = "fx" },
  { level = 3, name = "fx_vox_dly",      group = "fx", channels = 4 },
  { level = 3, name = "fx_vox_hall",     group = "fx", channels = 4 },

  -- Silent sidechain hubs: outside master_bus, never reach the master.
  { level = 0, name = "sc_kick",         group = "hub", parent_send = false, sends = {
      key_out("bass_low"), key_out("syn_sub"),
  } },
  { level = 0, name = "sc_snare",        group = "hub", parent_send = false, sends = {
      key_out("gtr_rhy_bus"), key_out("orch_syn_bus"),
  } },
  { level = 0, name = "sc_spotlight",    group = "hub", parent_send = false, sends = {
      key_out("instrument_bus"), key_out("fx_inst_plate"), key_out("fx_inst_dly"),
      key_out("fx_vox_plate"), key_out("fx_vox_dly"), key_out("fx_vox_hall"),
  } },
}

-- REAPER visual spacer (TCP gap) above each listed track. Sections, then subsections.
local SPACER_ABOVE = {
  -- sections
  "bass_bus", "gtr_rhy_bus", "orch_syn_bus", "sfx_bus", "fx_inst_plate", "vocal_master", "sc_kick",
  -- drum subsections
  "kick_bus", "snr_bus", "tom_bus", "oh_cym_bus", "room_bus", GGD_TRACK_NAME,
  -- bass, guitar, orch/synth and vocal subsections
  "bass_high", "bass_di", "gtr_ld_bus", "gtr_mel_bus", "syn_pad", "fx_hall", "vox_bgv_bus", "fx_vox_plate",
}

--------------------------------------------------------------------------------
-- BUILDER. No edits needed below.
--------------------------------------------------------------------------------

local SEND_MODE = { post = 0, prefx = 1, pre = 3 }
local CATEGORY_SEND = 0
local MB_YESNO, MB_OK, MB_ANSWER_YES = 4, 0, 6
local CUSTOM_COLOR_FLAG = 0x1000000
local MONO_FLAG = 1024
local CHANNEL_COUNT_SHIFT = 1024
local MIDI_SEND_DISABLED = 31
local STEREO_TO_PARENT = 2
local SPACER_ON = 1  -- I_SPACER: 1 = TCP track spacer above this track (ReaScript API, REAPER 7.86)

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

local function db_to_gain(db) return 10 ^ (db / 20) end

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

local function create_tracks(tracks, first_index)
  local handles = {}
  local depth_changes = folder_depth_changes(tracks)
  local spacer_above = {}
  for _, name in ipairs(SPACER_ABOVE) do spacer_above[name] = true end
  for i, track in ipairs(tracks) do
    local index = first_index + i - 1
    reaper.InsertTrackAtIndex(index, false)
    local handle = reaper.GetTrack(0, index)
    reaper.GetSetMediaTrackInfo_String(handle, "P_NAME", track.name, true)
    reaper.SetMediaTrackInfo_Value(handle, "I_NCHAN", track.channels)
    reaper.SetMediaTrackInfo_Value(handle, "B_MAINSEND", track.parent_send and 1 or 0)
    reaper.SetMediaTrackInfo_Value(handle, "I_CUSTOMCOLOR", native_color(track.group, depth_changes[i] > 0))
    reaper.SetMediaTrackInfo_Value(handle, "I_FOLDERDEPTH", depth_changes[i])
    if spacer_above[track.name] then reaper.SetMediaTrackInfo_Value(handle, "I_SPACER", SPACER_ON) end
    if track.parent_send and track.channels > STEREO_TO_PARENT then
      -- Keeps sidechain keys on 3/4 out of the parent bus.
      reaper.SetMediaTrackInfo_Value(handle, "C_MAINSEND_NCH", STEREO_TO_PARENT)
    end
    handles[track.name] = handle
  end
  return handles
end

local function create_sends(tracks, handles)
  local created = 0
  for _, track in ipairs(tracks) do
    local source = handles[track.name]
    for _, send in ipairs(track.sends) do
      local send_index = reaper.CreateTrackSend(source, handles[send.to])
      if send_index >= 0 then
        reaper.SetTrackSendInfo_Value(source, CATEGORY_SEND, send_index, "I_SENDMODE", SEND_MODE[send.mode])
        reaper.SetTrackSendInfo_Value(source, CATEGORY_SEND, send_index, "D_VOL", db_to_gain(send.db))
        reaper.SetTrackSendInfo_Value(source, CATEGORY_SEND, send_index, "I_SRCCHAN", encode_src_channels(send.src))
        reaper.SetTrackSendInfo_Value(source, CATEGORY_SEND, send_index, "I_DSTCHAN", encode_dst_channels(send.dst))
        reaper.SetTrackSendInfo_Value(source, CATEGORY_SEND, send_index, "I_MIDIFLAGS", MIDI_SEND_DISABLED)
        created = created + 1
      end
    end
  end
  return created
end

local function user_confirms_append(existing_count)
  local message = string.format(
    "This project already has %d tracks.\n\nYes = add the WAP template after them.\nNo = cancel.\n\nExisting tracks are never deleted.",
    existing_count)
  return reaper.MB(message, UNDO_LABEL, MB_YESNO) == MB_ANSWER_YES
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
  reaper.ShowConsoleMsg("No plugins were added. Hub keys arrive on channels 3/4: point each detector at Auxiliary Input.\n")
end

local function main()
  local tracks = {}
  for i, entry in ipairs(TEMPLATE) do tracks[i] = with_defaults(entry) end

  local errors = validate(tracks)
  if #errors > 0 then
    reaper.MB("TEMPLATE has errors. Nothing was changed.\n\n" .. table.concat(errors, "\n"), UNDO_LABEL, MB_OK)
    return
  end

  local existing_count = reaper.CountTracks(0)
  if existing_count > 0 and not user_confirms_append(existing_count) then return end

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

main()
