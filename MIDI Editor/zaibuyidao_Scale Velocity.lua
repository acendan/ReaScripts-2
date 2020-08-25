--[[
 * ReaScript Name: Scale Velocity
 * Instructions: Open a MIDI take in MIDI Editor. Select Notes. Run.
 * Version: 2.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-01-23)
  + Initial release
--]]

function main()
  local take=reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  if take == nil then return end
  local cnt, index = 0, {}
  local val = reaper.MIDI_EnumSelNotes(take, -1)
  while val ~= - 1 do
    cnt = cnt + 1
    index[cnt] = val
    val = reaper.MIDI_EnumSelNotes(take, val)
  end
  reaper.Undo_BeginBlock()
  reaper.MIDI_DisableSort(take)
  if #index > 0 then
    local vel_start = reaper.GetExtState("ScaleVelocityEV", "Start")
    local vel_end = reaper.GetExtState("ScaleVelocityEV", "End")
    local toggle = reaper.GetExtState("ScaleVelocityEV", "Toggle")
    if (vel_start == "") then vel_start = "100" end
    if (vel_end == "") then vel_end = "100" end
    if (toggle == "") then toggle = "0" end
    local userOK, userInputsCSV = reaper.GetUserInputs("Scale Velocity", 3, "Begin,End,0=Default 1=Percentages", vel_start..','..vel_end..','.. toggle)
    if not userOK then return reaper.SN_FocusMIDIEditor() end
    vel_start, vel_end, toggle = userInputsCSV:match("(%d*),(%d*),(%d*)")
    if not vel_start:match('[%d%.]+') or not vel_end:match('[%d%.]+') or not toggle:match('[%d%.]+') then return reaper.SN_FocusMIDIEditor() end
    reaper.SetExtState("ScaleVelocityEV", "Start", vel_start, false)
    reaper.SetExtState("ScaleVelocityEV", "End", vel_end, false)
    reaper.SetExtState("ScaleVelocityEV", "Toggle", toggle, false)
    local _, _, _, begin_ppqpos, _, _, _, _ = reaper.MIDI_GetNote(take, index[1])
    local _, _, _, end_ppqpos, _, _, _, _ = reaper.MIDI_GetNote(take, index[#index])
    local ppq_offset = (vel_end - vel_start) / (end_ppqpos - begin_ppqpos)
    for i = 1, #index do
      local _, _, _, startppqpos, _, _, _, vel = reaper.MIDI_GetNote(take, index[i])
      if toggle == "1" then
        if end_ppqpos ~= begin_ppqpos then
          new_vel = vel * (((startppqpos - begin_ppqpos) * ppq_offset + vel_start) / 100)
          x = math.floor(new_vel)
        else
          x = vel_start
        end
      else
        if end_ppqpos ~= begin_ppqpos then
          new_vel = (startppqpos - begin_ppqpos) * ppq_offset + vel_start
          x = math.floor(new_vel)
        else
          x = vel_start
        end
      end
      if x > 127 then x = 127 elseif x < 1 then x = 1 end
      reaper.MIDI_SetNote(take, index[i], nil, nil, nil, nil, nil, nil, x, false)
    end
  -- else
  --   reaper.MB("Please select one or more notes","Error",0)
  end
  reaper.MIDI_Sort(take)
  reaper.Undo_EndBlock("Scale Velocity", 0)
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
if CFNV then main() end
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()