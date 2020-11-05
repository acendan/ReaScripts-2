--[[
 * ReaScript Name: Move Items To The Track Of Selected First Item
 * Version: 1.0
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository: GitHub > zaibuyidao > ReaScripts
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * REAPER: 6.0
--]]

--[[
 * Changelog:
 * v1.0 (2020-11-6)
  + Initial release
--]]

function Msg(param) reaper.ShowConsoleMsg(tostring(param) .. "\n") end

count_sel_items = reaper.CountSelectedMediaItems(0)

if count_sel_items > 0 then
    reaper.PreventUIRefresh(1)
    reaper.Undo_BeginBlock() -- 撤消塊開始
    for i = 0, count_sel_items - 1 do
        item = reaper.GetSelectedMediaItem(0, i)
        if i == 0 then 
          track = reaper.GetMediaItem_Track(item)
        end
        reaper.MoveMediaItemToTrack(item, track)
    end
    reaper.Undo_EndBlock("Move Items To The Track Of Selected First Item", -1) -- 撤消塊末尾
    reaper.UpdateArrange()
    reaper.PreventUIRefresh(-1)
end
