--[[
 * ReaScript Name: Set CC Value
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

local retval, x = reaper.GetUserInputs('Set CC Value', 1, 'Value', '100')
if not retval then return reaper.SN_FocusMIDIEditor() end
x = tonumber(x)

if x > 127 or x < 1 then
    return reaper.MB("Please enter a value from 1 through 127", "Error", 0),
           reaper.SN_FocusMIDIEditor()
end

function Main()
  local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
  retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
  for i = 0,  ccs-1 do
    retval, sel, muted, ppqpos, chanmsg, chan, msg2, msg3 = reaper.MIDI_GetCC(take, i)
    if sel == true then
      reaper.MIDI_SetCC(take, i, sel, mutedIn, ppqposIn, chanmsgIn, chanIn, msg2In, x, true)
    end
    i=i+1
  end
  reaper.UpdateArrange()
end

script_title = "Set CC Value"
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock(script_title, -1)
reaper.SN_FocusMIDIEditor()
