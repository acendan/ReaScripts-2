-- @description 事件過濾 - 選擇控制器(快速)
-- @version 1.0.1
-- @author 再補一刀
-- @changelog Optimized code
-- @links
--   webpage https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
--   repo https://github.com/zaibuyidao/ReaScripts
-- @donate http://www.paypal.me/zaibuyidao
-- @about Requires SWS Extensions

function print(...)
    local params = {...}
    for i = 1, #params do
        if i ~= 1 then reaper.ShowConsoleMsg(" ") end
        reaper.ShowConsoleMsg(tostring(params[i]))
    end
    reaper.ShowConsoleMsg("\n")
end

function table.print(t)
  local print_r_cache = {}
  local function sub_print_r(t, indent)
      if (print_r_cache[tostring(t)]) then
          print(indent .. "*" .. tostring(t))
      else
          print_r_cache[tostring(t)] = true
          if (type(t) == "table") then
              for pos, val in pairs(t) do
                  if (type(val) == "table") then
                      print(indent .. "[" .. tostring(pos) .. "] => " ..
                                tostring(t) .. " {")
                      sub_print_r(val, indent ..
                                      string.rep(" ",
                                                 string.len(tostring(pos)) + 8))
                      print(indent ..
                                string.rep(" ", string.len(tostring(pos)) + 6) ..
                                "}")
                  elseif (type(val) == "string") then
                      print(
                          indent .. "[" .. tostring(pos) .. '] => "' .. val ..
                              '"')
                  else
                      print(indent .. "[" .. tostring(pos) .. "] => " ..
                                tostring(val))
                  end
              end
          else
              print(indent .. tostring(t))
          end
      end
  end
  if (type(t) == "table") then
      print(tostring(t) .. " {")
      sub_print_r(t, "  ")
      print("}")
  else
      sub_print_r(t, "  ")
  end
end

function open_url(url)
    if not OS then local OS = reaper.GetOS() end
    if OS=="OSX32" or OS=="OSX64" then
      os.execute("open ".. url)
     else
      os.execute("start ".. url)
    end
end

if not reaper.SN_FocusMIDIEditor then
    local retval = reaper.ShowMessageBox("This script requires the SWS extension, would you like to download it now?\n\n這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
    if retval == 1 then
      open_url("http://www.sws-extension.org/download/pre-release/")
    end
end

function clone(object)
  local lookup_table = {}
  local function _copy(object)
      if type(object) ~= "table" then
          return object
      elseif lookup_table[object] then
          return lookup_table[object]
      end
      local new_table = {}
      lookup_table[object] = new_table
      for key, value in pairs(object) do
          new_table[_copy(key)] = _copy(value)
      end
      return setmetatable(new_table, getmetatable(object))
  end
  return _copy(object)
end

local floor = math.floor
function math.floor(x) return floor(x + 0.0000005) end

EVENT_NOTE_START = 9
EVENT_NOTE_END = 8
EVENT_WHEEL = 14
EVENT_CC = 11
EVENT_ARTICULATION = 15

function setAllEvents(take, events)
  local lastPos = 0
  for _, event in pairs(events) do
      event.offset = event.pos - lastPos
      lastPos = event.pos
  end
  local tab = {}
  for _, event in pairs(events) do
      table.insert(tab, string.pack("i4Bs4", event.offset, event.flags, event.msg))
  end
  reaper.MIDI_SetAllEvts(take, table.concat(tab))
end

function getAllEvents(take, onEach)
  local getters = {
      selected = function(event) return event.flags & 1 == 1 end,
      msg2 = function(event) return event.msg:byte(2) end,
      msg3 = function(event) return event.msg:byte(3) end,
      type = function(event) return event.msg:byte(1) >> 4 end,
      channel = function(event) return event.msg:byte(1)&0x0F end
  }
  local setters = {
      msg2 = function(event, value)
          event.msg = string.pack("BBB", event.msg:byte(1), value or event.msg:byte(2), event.msg:byte(3))
      end,
      msg3 = function(event, value)
          event.msg = string.pack("BBB", event.msg:byte(1), event.msg:byte(2), value or event.msg:byte(3))
      end,
      selected = function(event, value)
          if value then
              event.flags = event.flags | 1
          else
              event.flags = event.flags & 0xFFFFFFFE
          end
      end
  }
  local eventMetaTable = {
      __index = function(event, key) return getters[key](event) end,
      __newindex = function(event, key, value)
          return setters[key](event, value)
      end
  }

  local events = {}
  local _, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
  local stringPos = 1
  local lastPos = 0
  while stringPos <= MIDIstring:len() do
      local offset, flags, msg
      offset, flags, msg, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)
      local event = setmetatable({
          offset = offset,
          pos = lastPos + offset,
          flags = flags,
          msg = msg
      }, eventMetaTable)
      table.insert(events, event)
      onEach(event)
      lastPos = lastPos + offset
  end
  return events
end

function getAllTakes()
  tTake = {}
  if reaper.MIDIEditor_EnumTakes then
      local editor = reaper.MIDIEditor_GetActive()
      for i = 0, math.huge do
          take = reaper.MIDIEditor_EnumTakes(editor, i, false)
          if take and reaper.ValidatePtr2(0, take, "MediaItem_Take*") then
              tTake[take] = true
              tTake[take] = {item = reaper.GetMediaItemTake_Item(take)}
          else
              break
          end
      end
  else
      for i = 0, reaper.CountMediaItems(0) - 1 do
          local item = reaper.GetMediaItem(0, i)
          local take = reaper.GetActiveTake(item)
          if reaper.ValidatePtr2(0, take, "MediaItem_Take*") and
              reaper.TakeIsMIDI(take) and reaper.MIDI_EnumSelNotes(take, -1) == 0 then -- Get potential takes that contain notes. NB == 0 
              tTake[take] = true
          end
      end
      for take in next, tTake do
          if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then
            tTake[take] = nil
          end
      end
  end
  if not next(tTake) then return end
  return tTake
end

local min_num = reaper.GetExtState("SelectControl", "MinNum")
if (min_num == "") then min_num = "0" end
local max_num = reaper.GetExtState("SelectControl", "MaxNum")
if (max_num == "") then max_num = "127" end
local min_val = reaper.GetExtState("SelectControl", "MinVal")
if (min_val == "") then min_val = "0" end
local max_val = reaper.GetExtState("SelectControl", "MaxVal")
if (max_val == "") then max_val = "127" end
local min_chan = reaper.GetExtState("SelectControl", "MinChan")
if (min_chan == "") then min_chan = "1" end
local max_chan = reaper.GetExtState("SelectControl", "MaxChan")
if (max_chan == "") then max_chan = "16" end
local min_meas = reaper.GetExtState("SelectControl", "MinMeas")
if (min_meas == "") then min_meas = "1" end
local max_meas = reaper.GetExtState("SelectControl", "MaxMeas")
if (max_meas == "") then max_meas = "99" end
local min_tick = reaper.GetExtState("SelectControl", "MinTick")
if (min_tick == "") then min_tick = "0" end
local max_tick = reaper.GetExtState("SelectControl", "MaxTick")
if (max_tick == "") then max_tick = "1919" end
local reset = reaper.GetExtState("SelectControl", "Reset")
if (reset == "") then reset = "0" end

user_ok, dialog_ret_vals = reaper.GetUserInputs("選擇控制器(快速)", 11, "編號,,數值,,通道,,拍子,,嘀嗒,,輸入1以恢復默認設置,", min_num ..','.. max_num ..','.. min_val ..','.. max_val ..','.. min_chan ..','.. max_chan ..','.. min_meas ..','.. max_meas ..','.. min_tick ..','.. max_tick ..','.. reset)
if not user_ok then return reaper.SN_FocusMIDIEditor() end
min_num, max_num, min_val, max_val, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick, reset = dialog_ret_vals:match("(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*),(.*)")
if not tonumber(min_num) or not tonumber(max_num) or not tonumber(min_val) or not tonumber(max_val) or not tonumber(min_chan) or not tonumber(max_chan) or not tonumber(min_meas) or not tonumber(max_meas) or not tonumber(min_tick) or not tonumber(max_tick) or not tonumber(reset) then return reaper.SN_FocusMIDIEditor() end
min_num, max_num, min_val, max_val, min_chan, max_chan, min_meas, max_meas, min_tick, max_tick, reset = tonumber(min_num), tonumber(max_num), tonumber(min_val), tonumber(max_val), tonumber(min_chan), tonumber(max_chan), tonumber(min_meas), tonumber(max_meas), tonumber(min_tick), tonumber(max_tick), tonumber(reset)

reaper.SetExtState("SelectControl", "MinNum", min_num, false)
reaper.SetExtState("SelectControl", "MaxNum", max_num, false)
reaper.SetExtState("SelectControl", "MinVal", min_val, false)
reaper.SetExtState("SelectControl", "MaxVal", max_val, false)
reaper.SetExtState("SelectControl", "MinChan", min_chan, false)
reaper.SetExtState("SelectControl", "MaxChan", max_chan, false)
reaper.SetExtState("SelectControl", "MinMeas", min_meas, false)
reaper.SetExtState("SelectControl", "MaxMeas", max_meas, false)
reaper.SetExtState("SelectControl", "MinTick", min_tick, false)
reaper.SetExtState("SelectControl", "MaxTick", max_tick, false)

min_chan = min_chan - 1
max_chan = max_chan - 1
min_meas = min_meas - 1

if reset == 1 then
    reaper.SetExtState("SelectControl", "MinNum", "0", false)
    reaper.SetExtState("SelectControl", "MaxNum", "127", false)
    reaper.SetExtState("SelectControl", "MinVal", "0", false)
    reaper.SetExtState("SelectControl", "MaxVal", "127", false)
    reaper.SetExtState("SelectControl", "MinChan", "1", false)
    reaper.SetExtState("SelectControl", "MaxChan", "16", false)
    reaper.SetExtState("SelectControl", "MinMeas", "1", false)
    reaper.SetExtState("SelectControl", "MaxMeas", "99", false)
    reaper.SetExtState("SelectControl", "MinTick", "0", false)
    reaper.SetExtState("SelectControl", "MaxTick", "1919", false)
    reaper.SetExtState("SelectControl", "Reset", "0", false)
    return
end

local midi_tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
for take, _ in pairs(getAllTakes()) do
  local last_note_event_at_pitch = {}
  local pitch_events = {}

  local events = getAllEvents(take, function(event)
    if not event.selected then
      goto continue
    end

    if event.type == EVENT_CC then
      last_note_event_at_pitch[event.msg2] = event
      table.insert(pitch_events, {left = last_note_event_at_pitch[event.msg2]})
      last_note_event_at_pitch[event.msg2] = nil
    end

    ::continue::
  end)
  for _, note_event in pairs(pitch_events) do
    local startppqpos = note_event.left.pos
    local start_meas = reaper.MIDI_GetPPQPos_StartOfMeasure(take, startppqpos)
    local start_tick = startppqpos - start_meas
    local tick = start_tick % midi_tick

    note_event.left.selected =
          (note_event.left.msg2 >= min_num and note_event.left.msg2 <= max_num)
      and (note_event.left.msg3 >= min_val and note_event.left.msg3 <= max_val)
      and (note_event.left.channel >= min_chan and note_event.left.channel <= max_chan)
      and (start_tick >= min_meas * midi_tick and start_tick < max_meas * midi_tick)
      and (tick >= min_tick and tick <= max_tick)
  end
  setAllEvents(take, events)
end

reaper.Undo_EndBlock("選擇控制器(快速)", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()