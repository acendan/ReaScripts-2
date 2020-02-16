--[[
 * ReaScript Name: Scale Control (Enhanced Version)
 * Instructions: Open a MIDI take in MIDI Editor. Select CC Events. Run.
 * Version: 1.3
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.2 (2020-01-29)
  # Bug fix
 * v1.0 (2020-01-23)
  + Initial release
--]]

function Main()
  local script_title = "Scale Control (Enhanced Version)"
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelCC(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelCC(take, val)
  end
  reaper.Undo_BeginBlock()
  reaper.MIDI_DisableSort(take)
  if #index > 0 then
    local _, _, _, begin_ppqpos, _, _, _, begin_val = reaper.MIDI_GetCC(take, index[1])
    local _, _, _, end_ppqpos, _, _, _, end_val = reaper.MIDI_GetCC(take, index[#index])
    local cur_range = tostring(begin_val)..','..tostring(end_val)..','.."1"
    local retval, userInputsCSV = reaper.GetUserInputs("Scale Control", 3, "Begin,End,0=Default 1=Percentages", cur_range)
    if not retval then return reaper.SN_FocusMIDIEditor() end
    local val_start, val_end, toggle = userInputsCSV:match("(%d*),(%d*),(%d*)")
    if not val_start:match('[%d%.]+') or not val_end:match('[%d%.]+') then return reaper.SN_FocusMIDIEditor() end
    val_start, val_end, toggle = tonumber(val_start), tonumber(val_end), tonumber(toggle)
    reaper.SetExtState("ScaleControl", "ToggleValue", toggle, true)
    local ppq_offset = (val_end - val_start) / (end_ppqpos - begin_ppqpos)
    local val_offset = (val_end - val_start) / (cnt - 1)
    local has_state = reaper.HasExtState("ScaleControl", "ToggleValue")
    if has_state == true then
      state = reaper.GetExtState("ScaleControl", "ToggleValue")
    end
    for i = 1, #index do
      local _, _, _, ppqpos, _, _, _, vel = reaper.MIDI_GetCC(take, index[i])
      if state == "1" then
        local x = math.floor(0.5 + vel*(val_start/100))
        if x > 127 then x = 127 elseif x < 1 then x = 1 end
        reaper.MIDI_SetCC(take, index[i], nil, nil, nil, nil, nil, nil, x, false)
        val_start = val_start + val_offset
      else
        if end_ppqpos ~= begin_ppqpos then
          local new_vel = (ppqpos - begin_ppqpos) * ppq_offset + val_start
          local y = math.floor(0.5 + new_vel)
          if y > 127 then y = 127 elseif y < 1 then y = 1 end
          reaper.MIDI_SetCC(take, index[i], nil, nil, nil, nil, nil, nil, y, false)
        else
          reaper.MIDI_SetCC(take, index[i], nil, nil, nil, nil, nil, nil, val_start, false)
        end
      end
    end
  else
    reaper.MB("Please select one or more CC events","Error",0)
  end
  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock(script_title, 0)
end

function CheckForNewVersion(new_version)
    local app_version = reaper.GetAppVersion()
    app_version = tonumber(app_version:match('[%d%.]+'))
    if new_version > app_version then
      reaper.MB('Update REAPER to newer version '..'('..new_version..' or newer)', '', 0)
      return
     else
      return true
    end
end

local CFNV = CheckForNewVersion(6.03)
if CFNV then Main() end
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
