-- WAP: normalize tracks to common gain.
-- Per track, one gain moves every audio item so the loudest item peaks at TARGET_PEAK_DBFS.
-- Processes every track in the project. Pure REAPER API.

local TARGET_PEAK_DBFS = -10.0

-- REAPER almost always has a track selected (the last one clicked), so selection-only
-- mode is off by default. Set true to process only the selected tracks.
local ONLY_SELECTED_TRACKS = false

-- DI level is the amp sim's input gain. Normalize DIs before you dial the amps, so every
-- song hits the amp at the same level. If the amps are already dialed, set this true:
-- moving the DI level would change the amp tone. Matches bass_di, gtr_rhy_l_di.
local SKIP_DI_TRACKS = false
local DI_TRACK_NAME_PATTERN = "_di$"

local UNDO_LABEL = "WAP: normalize tracks to common gain"
local UNDO_ALL_STATE = -1
local READ_BLOCK_FRAMES = 8192
local FALLBACK_SAMPLE_RATE = 48000
local UNITY_VOLUME = 1.0

local function db_to_linear(db)
  return 10 ^ (db / 20)
end

local function linear_to_db(linear)
  return 20 * math.log(linear) / math.log(10)
end

local function is_di_track(track_name)
  return string.lower(track_name):find(DI_TRACK_NAME_PATTERN) ~= nil
end

local function get_audio_take(item)
  local take = reaper.GetActiveTake(item)
  if not take or reaper.TakeIsMIDI(take) then
    return nil
  end
  local source = reaper.GetMediaItemTake_Source(take)
  if not source then
    return nil
  end
  return take, source
end

local function read_accessor_peak(take, source)
  local sample_rate = reaper.GetMediaSourceSampleRate(source)
  if sample_rate <= 0 then
    sample_rate = FALLBACK_SAMPLE_RATE
  end
  local channel_count = math.max(1, reaper.GetMediaSourceNumChannels(source))

  local accessor = reaper.CreateTakeAudioAccessor(take)
  local start_time = reaper.GetAudioAccessorStartTime(accessor)
  local end_time = reaper.GetAudioAccessorEndTime(accessor)
  local total_frames = math.ceil((end_time - start_time) * sample_rate)
  local buffer = reaper.new_array(READ_BLOCK_FRAMES * channel_count)

  local peak = 0
  local frames_read = 0
  local is_read_ok = true
  while frames_read < total_frames do
    local block_frames = math.min(READ_BLOCK_FRAMES, total_frames - frames_read)
    local block_start_time = start_time + frames_read / sample_rate
    buffer.clear()
    local read_status = reaper.GetAudioAccessorSamples(
      accessor, sample_rate, channel_count, block_start_time, block_frames, buffer)
    if read_status < 0 then
      is_read_ok = false
      break
    end
    if read_status == 1 then
      local samples = buffer.table(1, block_frames * channel_count)
      for i = 1, #samples do
        local magnitude = math.abs(samples[i])
        if magnitude > peak then
          peak = magnitude
        end
      end
    end
    frames_read = frames_read + block_frames
  end

  reaper.DestroyAudioAccessor(accessor)
  if not is_read_ok then
    return nil
  end
  return peak
end

-- The API doc does not say if a take accessor applies item or take volume, so both are held at unity while reading.
local function measure_raw_peak(item, take, source, item_volume, take_volume)
  reaper.SetMediaItemInfo_Value(item, "D_VOL", UNITY_VOLUME)
  reaper.SetMediaItemTakeInfo_Value(take, "D_VOL", UNITY_VOLUME)
  local is_ok, peak_or_error = pcall(read_accessor_peak, take, source)
  reaper.SetMediaItemInfo_Value(item, "D_VOL", item_volume)
  reaper.SetMediaItemTakeInfo_Value(take, "D_VOL", take_volume)
  if not is_ok then
    error(peak_or_error)
  end
  return peak_or_error
end

local function measure_track_items(track)
  local measured_items = {}
  local audio_item_count = 0
  local silent_item_count = 0
  for item_index = 0, reaper.CountTrackMediaItems(track) - 1 do
    local item = reaper.GetTrackMediaItem(track, item_index)
    local take, source = get_audio_take(item)
    if take then
      audio_item_count = audio_item_count + 1
      local item_volume = reaper.GetMediaItemInfo_Value(item, "D_VOL")
      local take_volume = reaper.GetMediaItemTakeInfo_Value(take, "D_VOL")
      local raw_peak = measure_raw_peak(item, take, source, item_volume, take_volume) or 0
      -- Take D_VOL is negative when polarity is flipped; level uses its magnitude.
      local current_peak = raw_peak * item_volume * math.abs(take_volume)
      if current_peak > 0 then
        measured_items[#measured_items + 1] = {
          take = take,
          take_volume = take_volume,
          current_peak = current_peak,
        }
      else
        silent_item_count = silent_item_count + 1
      end
    end
  end
  return measured_items, audio_item_count, silent_item_count
end

local function compute_common_gain(measured_items, target_peak_linear)
  local loudest_peak = 0
  for _, measured in ipairs(measured_items) do
    if measured.current_peak > loudest_peak then
      loudest_peak = measured.current_peak
    end
  end
  return target_peak_linear / loudest_peak
end

local function collect_target_tracks()
  local tracks = {}
  if ONLY_SELECTED_TRACKS then
    for i = 0, reaper.CountSelectedTracks(0) - 1 do
      tracks[#tracks + 1] = reaper.GetSelectedTrack(0, i)
    end
  else
    for i = 0, reaper.CountTracks(0) - 1 do
      tracks[#tracks + 1] = reaper.GetTrack(0, i)
    end
  end
  return tracks, ONLY_SELECTED_TRACKS
end

local function normalize_track(track, target_peak_linear)
  local measured_items, audio_item_count, silent_item_count = measure_track_items(track)
  if audio_item_count == 0 then
    return nil, "no audio items"
  end
  if #measured_items == 0 then
    return nil, "all audio items silent"
  end
  local common_gain = compute_common_gain(measured_items, target_peak_linear)
  for _, measured in ipairs(measured_items) do
    reaper.SetMediaItemTakeInfo_Value(measured.take, "D_VOL", measured.take_volume * common_gain)
  end
  return {
    gain_db = linear_to_db(common_gain),
    item_count = #measured_items,
    silent_item_count = silent_item_count,
  }
end

local function main()
  local target_peak_linear = db_to_linear(TARGET_PEAK_DBFS)
  local tracks, is_selection_scope = collect_target_tracks()
  local report_lines = {}
  local skipped_lines = {}

  for _, track in ipairs(tracks) do
    local _, track_name = reaper.GetTrackName(track)
    if SKIP_DI_TRACKS and is_di_track(track_name) then
      skipped_lines[#skipped_lines + 1] = string.format("  %s: DI track, SKIP_DI_TRACKS is on", track_name)
    else
      local result, skip_reason = normalize_track(track, target_peak_linear)
      if result then
        local silent_note = ""
        if result.silent_item_count > 0 then
          silent_note = string.format(", %d silent skipped", result.silent_item_count)
        end
        report_lines[#report_lines + 1] = string.format("  %s: %+.2f dB, %d items%s",
          track_name, result.gain_db, result.item_count, silent_note)
      else
        skipped_lines[#skipped_lines + 1] = string.format("  %s: %s", track_name, skip_reason)
      end
    end
  end

  local scope_label = is_selection_scope and "selected tracks" or "all tracks"
  local console_text = string.format("%s (%s, target %.1f dBFS peak)\n", UNDO_LABEL, scope_label, TARGET_PEAK_DBFS)
  console_text = console_text .. "Normalized:\n"
  if #report_lines == 0 then
    console_text = console_text .. "  none\n"
  else
    console_text = console_text .. table.concat(report_lines, "\n") .. "\n"
  end
  if #skipped_lines > 0 then
    console_text = console_text .. "Skipped:\n" .. table.concat(skipped_lines, "\n") .. "\n"
  end
  reaper.ShowConsoleMsg(console_text)
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)
local is_ok, error_message = pcall(main)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock(UNDO_LABEL, UNDO_ALL_STATE)
if not is_ok then
  reaper.ShowConsoleMsg("WAP normalize failed: " .. tostring(error_message) .. "\n")
end
