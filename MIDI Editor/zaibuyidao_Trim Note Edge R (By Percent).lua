--[[
 * ReaScript Name: Trim Note Edge R (By Percent)
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2019-12-12)
     + Initial Release
--]]

reaper.Undo_BeginBlock()
local take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
retval, notes, ccs, sysex = reaper.MIDI_CountEvts(take)
local retval, j = reaper.GetUserInputs("Trim Note Edge R", 1, "By Percent", "200")
if not retval then return reaper.SN_FocusMIDIEditor() end

for i = 0,  notes-1 do
  retval, sel, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
  if sel == true then
    local len = endppqpos-startppqpos
    reaper.MIDI_SetNote(take, i, sel, muted, startppqpos, endppqpos+len*(j/100)-len, chan, pitch, vel, true)
  end
  i=i+1
end

reaper.UpdateArrange()
reaper.Undo_EndBlock("Trim Note Edge R", -1)
reaper.SN_FocusMIDIEditor()
