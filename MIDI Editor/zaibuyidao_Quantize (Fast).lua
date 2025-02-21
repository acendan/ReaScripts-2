--[[
 * ReaScript Name: Quantize (Fast)
 * Version: 1.0.7
 * Author: zaibuyidao
 * Author URI: https://www.soundengine.cn/user/%E5%86%8D%E8%A3%9C%E4%B8%80%E5%88%80
 * Repository URI: https://github.com/zaibuyidao/ReaScripts
 * Donation: http://www.paypal.me/zaibuyidao
--]]

--[[
 * Changelog:
 * v1.0 (2021-2-15)
  + Initial release
--]]

EVENT_NOTE_START = 9
EVENT_NOTE_END = 8
EVENT_ARTICULATION = 15

function print(...)
    local params = {...}
    for i=1, #params do
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
                        print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(t) .. " {")
                        sub_print_r(val, indent .. string.rep(" ", string.len(tostring(pos)) + 8))
                        print(indent .. string.rep(" ", string.len(tostring(pos)) + 6) .. "}")
                    elseif (type(val) == "string") then
                        print(indent .. "[" .. tostring(pos) .. '] => "' .. val .. '"')
                    else
                        print(indent .. "[" .. tostring(pos) .. "] => " .. tostring(val))
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

if not reaper.SNM_GetIntConfigVar then
    local retval = reaper.ShowMessageBox("This script requires the SWS extension, would you like to download it now?\n\n這個脚本需要SWS擴展，你想現在就下載它嗎？", "Warning", 1)
    if retval == 1 then
        open_url("http://www.sws-extension.org/download/pre-release/")
    end
end

function getAllTakes()
    tTake = {}
    if reaper.MIDIEditor_EnumTakes then
        local editor = reaper.MIDIEditor_GetActive()
        for i = 0, math.huge do
            take = reaper.MIDIEditor_EnumTakes(editor, i, false)
            if take and reaper.ValidatePtr2(0, take, "MediaItem_Take*") then 
                tTake[take] = true
                tTake[take] = {item = reaper.GetMediaItemTake_Item(take), editor = editor}
            else
                break
            end
        end
    else
        for i = 0, reaper.CountMediaItems(0)-1 do
            local item = reaper.GetMediaItem(0, i)
            local take = reaper.GetActiveTake(item)
            if reaper.ValidatePtr2(0, take, "MediaItem_Take*") and reaper.TakeIsMIDI(take) and reaper.MIDI_EnumSelNotes(take, -1) == 0 then -- Get potential takes that contain notes. NB == 0 
                tTake[take] = true
            end
        end
        
        for take in next, tTake do
            if reaper.MIDI_EnumSelNotes(take, -1) ~= -1 then tTake[take] = nil end -- Remove takes that were not affected by deselection
        end
    end
    if not next(tTake) then return end
    return tTake
end

function setAllEvents(take, events)
    -- -- 排序事件
    -- local last = events[#events]
    -- table.remove(events, #events) -- 排除 All-Note-Off 事件
    -- table.sort(events,function(a,b)
    --     -- if a.status == 11 then return false end
    --     if a.pos == b.pos then
    --         if a.status == b.status then
    --             return a.pitch < b.pitch
    --         end
    --         return a.status < b.status
    --     end
    --     return a.pos < b.pos
    -- end)
    -- table.insert(events, last)

    local lastPos = 0
    for _, event in pairs(events) do
        event.offset = event.pos - lastPos
        lastPos = event.pos
    end

    -- 构造事件字符串数据
    local tab = {}
    for _, event in pairs(events) do
        table.insert(tab, string.pack("i4Bs4", event.offset, event.flags, event.msg))
    end
    reaper.MIDI_SetAllEvts(take, table.concat(tab))
end

function min(a,b) if a>b then return b end return a end
function getEventPitch(event) return event.msg:byte(2) end
function getEventSelected(event) return event.flags&1 == 1 end
function getEventType(event) return event.msg:byte(1)>>4 end
function getArticulationInfo(event) return event.msg:match("NOTE (%d+) (%d+) ") end
function setEventPitch(event, pitch) event.msg = string.pack("BBB", event.msg:byte(1), pitch or event.msg:byte(2), event.msg:byte(3)) end

local tick = reaper.SNM_GetIntConfigVar("MidiTicksPerBeat", 480)
local active_take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive())
if not active_take or not reaper.TakeIsMIDI(active_take) then return end
local cur_gird, swing = reaper.MIDI_GetGrid(active_take)
local gird, toggle
local use_tick = false

if tonumber(swing) == 0 then
    gird = reaper.GetExtState("QuantizeFast", "Grid")
    if (gird == "") then gird = "240" end
    toggle = reaper.GetExtState("QuantizeFast", "Toggle")
    if (toggle == "") then toggle = "0" end
    qntick = reaper.GetExtState("QuantizeFast", "QNTick")
    if (qntick == "") then qntick = "1" end

    local user_ok, input_csv = reaper.GetUserInputs('Quantize (Fast)', 3, 'Enter A Value (0=Grid),0=Default 1=Start 2=End 3=Pos,Time Format: 0=100Ths 1=Ticks', gird ..','.. toggle ..','.. qntick)
    gird, toggle, qntick = input_csv:match("(.*),(.*),(.*)")

    if not user_ok or not tonumber(gird) or not tonumber(toggle) or not tonumber(qntick) then return reaper.SN_FocusMIDIEditor() end
    reaper.SetExtState("QuantizeFast", "Grid", gird, false)
    reaper.SetExtState("QuantizeFast", "Toggle", toggle, false)
    reaper.SetExtState("QuantizeFast", "QNTick", qntick, false)

    if qntick == "1" then
        gird = gird / tick
        use_tick = true
    elseif qntick == "0" then
        if tonumber(gird) > 4 then return end
        use_tick = false
    end

    gird = tonumber(gird)
    if (gird == 0 or gird == -1) then
        gird = cur_gird
    end
else
    toggle = reaper.GetExtState("QuantizeFast", "Toggle")
    if (toggle == "") then toggle = "0" end

    local user_ok, input_cav = reaper.GetUserInputs('Quantize (Fast)', 1, '0=Default 1=Start 2=End 3=Pos', toggle)
    toggle = input_cav
    if not user_ok or not tonumber(toggle) then return reaper.SN_FocusMIDIEditor() end
    reaper.SetExtState("QuantizeFast", "Toggle", toggle, false)

    gird = cur_gird
end

function find_measure_pos(beat)
    count_tempo_markers = reaper.CountTempoTimeSigMarkers(0)
    -- if count_tempo_markers <= 0 then error("count_tempo_markers is nil") end
    if count_tempo_markers <= 0 then return 0 end
    
    local cur = 0
    local last = 0
    local last_measure_pos = 0
    local last_timesig_num = 0
    
    for i = 0, count_tempo_markers - 1 do
        retval, pos, measure_pos, beat_pos, bpm, timesig_num, timesig_denom, lineartempoOut = reaper.GetTempoTimeSigMarker(0, i)
        cur = last + (measure_pos - last_measure_pos) * last_timesig_num
        if cur > beat then
            return last
        end
        last_measure_pos = measure_pos
        last_timesig_num = timesig_num
        last = cur
    end
    return cur
    -- error("could not find measure_pos")
end

-- 将fullbeat对齐到refs里的beat位置
-- refs是一个小节内由网格线和swing线的beat位置组成的列表
-- minpos 不允许对齐后的位置小于minpos
-- maxpos 不允许对齐后的位置大于maxpos
function align(fullbeat, refs, minpos, maxpos)
    minpos = minpos or -0xffff
    maxpos = maxpos or 0xffff
    local anspos
    for i = 2, #refs do
        if refs[i-1] > refs[i] then error("Illegal refs") end
        if fullbeat >= refs[i-1] and fullbeat <= refs[i] then
            local mid = refs[i-1] + (refs[i] - refs[i-1]) / 2
            if fullbeat < mid then
                anspos = i - 1
                break
            else
                anspos = i
                break
            end
        end
    end
    if not anspos then
        error("Error in aling fullbeat:" .. fullbeat .. " to " .. table.concat(refs, " "))
    end
    
    local function check_min()
        return refs[anspos] > minpos + 0.01
    end

    local function check_max()
        return refs[anspos] < maxpos - 0.01
    end

    if not check_min() then
        repeat
            anspos = anspos + 1
        until check_min()
    elseif not check_max() then
        repeat
            anspos = anspos - 1
        until check_max()
    end
    return refs[anspos]
end

-- 生成times个小节的refs网格线位置列表
-- gird_beat 网格线拍数单位
-- swing 窗口底部显示的swing百分比值
-- beat_start 小节开始位置
-- cml 一个小节的拍数
-- measure_pos 拍号开始位置
function get_refs(gird_beat, swing, beat_start, cml, measure_pos)
    local result = {}
    if beat_start < 0 then beat_start = 0 end

    local cur = beat_start -- 当前位置
    local right_bound = cur + cml -- 右边界
    if gird_beat > cml then
        gird_beat = gird_beat - gird_beat % cml -- 跨小节自动取小节的倍数
        -- Msg(measure_pos)
        -- Msg(beat_start)
        -- Msg(gird_beat)
        cur = measure_pos + gird_beat * math.floor((beat_start - measure_pos) / gird_beat)
        right_bound = cur + gird_beat * 4
        while cur < right_bound do
            table.insert(result, cur)
            cur = cur + gird_beat
        end
        return result
    end

    local swing_offset_beat = gird_beat / 2 * swing -- swing偏移长度

    local precur = cur

    -- 网格线
    while cur < right_bound do
        table.insert(result, cur)
        cur = cur + gird_beat * 2
    end

    -- swing线或网格线
    local cur_swing = precur + gird_beat + swing_offset_beat
    while cur_swing < right_bound do
        table.insert(result, cur_swing)
        cur_swing = cur_swing + gird_beat * 2
    end
    
    table.sort(result)

    -- 最终右边界
    while result[#result] < right_bound do
        table.insert(result, right_bound)
    end

    -- 最终右边界继续扩展一格
    table.insert(result, right_bound + gird_beat + swing_offset_beat)

    return result
end

function StartTimes(take, gird) -- 只量化音符的起始位置
    for i = 1, #noteEvents do
        local selected = getEventSelected(noteEvents[i].first)
        local startppqpos = noteEvents[i].first.pos
        local endppqpos = noteEvents[i].second.pos
        if selected then
            local start_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
            local end_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)

            -- 小节内的节拍位置
            -- 第几小节
            -- 一个小节占几拍
            -- 节拍位置
            -- 几分音符
            local start_beats, start_measures, start_cml, start_fullbeats, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_note_qn)
            local out_pos, out_ppq, out_beatpos
            -- Msg("startppqpos:" .. startppqpos)
            -- Msg("start_note_qn:" .. start_note_qn)
            -- Msg("start_beats:" .. start_beats .. " start_fullbeats:" .. start_fullbeats)
            -- Msg("start_measures:" .. start_measures)
            -- Msg("start_cml:" .. start_cml .. " start_cdenom:" .. start_cdenom)

            local align_gird = gird
            if swing ~= 0 then align_gird = gird * start_cdenom / 4 end
            if use_tick then align_gird = gird * start_cdenom / 4 end
            local refs = get_refs(align_gird, swing, start_fullbeats - start_beats, start_cml, find_measure_pos(start_fullbeats))
            out_beatpos = align(start_fullbeats, refs)

            -- Msg("aling start " .. start_fullbeats .. " to " .. table.concat(refs, " ") .. " is " .. out_beatpos)
            out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
            out_ppq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, out_pos))
            noteEvents[i].first.pos = out_ppq
            if noteEvents[i].articulation then noteEvents[i].articulation.pos = noteEvents[i].first.pos end
        end
    end
end

function EndTimes(take, gird) -- 只量化音符结束位置
    for i = 1, #noteEvents do
        local selected = getEventSelected(noteEvents[i].first)
        local startppqpos = noteEvents[i].first.pos
        local endppqpos = noteEvents[i].second.pos
        if selected then
            local start_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
            local end_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)
            local start_beats, start_measures, start_cml, start_fullbeats, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_note_qn)
            local end_beats, end_measures, end_cml, end_fullbeats, end_cdenom = reaper.TimeMap2_timeToBeats(0, end_note_qn)
            local out_pos, out_ppq, out_beatpos

            local align_gird = gird
            if swing ~= 0 then align_gird = gird * start_cdenom / 4 end
            if use_tick then align_gird = gird * start_cdenom / 4 end
            local refs = get_refs(align_gird, swing, end_fullbeats - end_beats, end_cml, find_measure_pos(end_fullbeats))
            out_beatpos = align(end_fullbeats, refs, start_fullbeats)

            -- Msg("aling end " .. end_fullbeats .. " to " .. table.concat(refs, " ") .. " is " .. out_beatpos)
            out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
            out_ppq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, out_pos))
            noteEvents[i].second.pos = out_ppq
        end
    end
end

function Position(take, gird) -- 只移动（不是量化）音符的起始位置，移动到网格位置。
    for i = 1, #noteEvents do
        local selected = getEventSelected(noteEvents[i].first)
        local startppqpos = noteEvents[i].first.pos
        local endppqpos = noteEvents[i].second.pos
        if selected then
            local start_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, startppqpos)
            local end_note_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, endppqpos)
            local start_beats, start_measures, start_cml, start_fullbeats, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_note_qn)
            local out_pos, out_ppq, out_beatpos

            local align_gird = gird
            if swing ~= 0 then align_gird = gird * start_cdenom / 4 end
            if use_tick then align_gird = gird * start_cdenom / 4 end
            local refs = get_refs(align_gird, swing, start_fullbeats - start_beats, start_cml, find_measure_pos(start_fullbeats))
            out_beatpos = align(start_fullbeats, refs)

            out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
            out_ppq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, out_pos))
            endppqpos = endppqpos - (startppqpos - out_ppq)
            noteEvents[i].first.pos = out_ppq
            noteEvents[i].second.pos = endppqpos
            if noteEvents[i].articulation then noteEvents[i].articulation.pos = noteEvents[i].first.pos end
        end
    end
end

function CCEvents(take, gird) -- 仅量化CC位置，只在默认使用
    for i = 1, #ccEvents do
        local selected = getEventSelected(ccEvents[i])
        local ppqpos = ccEvents[i].pos
        if selected then
            local start_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)
            local start_beats, start_measures, start_cml, start_fullbeats, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_qn)
            local out_pos, out_ppq, out_beatpos

            local align_gird = gird
            if swing ~= 0 then align_gird = gird * start_cdenom / 4 end
            if use_tick then align_gird = gird * start_cdenom / 4 end
            local refs = get_refs(align_gird, swing, start_fullbeats - start_beats, start_cml, find_measure_pos(start_fullbeats))
            out_beatpos = align(start_fullbeats, refs)

            out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
            out_ppq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, out_pos))
            ccEvents[i].pos = out_ppq
        end
    end
end

function TextEvents(take, gird) -- 量化文本事件，只在默认使用
    for i = 1, #textEvents do
        local selected = getEventSelected(textEvents[i])
        local ppqpos = textEvents[i].pos
        if selected then
            local start_qn = reaper.MIDI_GetProjTimeFromPPQPos(take, ppqpos)
            local start_beats, start_measures, start_cml, start_fullbeats, start_cdenom = reaper.TimeMap2_timeToBeats(0, start_qn)
            local out_pos, out_ppq, out_beatpos
            
            local align_gird = gird
            if swing ~= 0 then align_gird = gird * start_cdenom / 4 end
            if use_tick then align_gird = gird * start_cdenom / 4 end
            local refs = get_refs(align_gird, swing, start_fullbeats - start_beats, start_cml, find_measure_pos(start_fullbeats))
            out_beatpos = align(start_fullbeats, refs)

            out_pos = reaper.TimeMap2_beatsToTime(0, out_beatpos)
            out_ppq = math.floor(reaper.MIDI_GetPPQPosFromProjTime(take, out_pos))
            textEvents[i].pos = out_ppq
        end
    end
end

reaper.Undo_BeginBlock()
for take, _ in pairs(getAllTakes()) do
    sourceLengthTicks = reaper.BR_GetMidiSourceLenPPQ(take)
    -- reaper.MIDIEditor_OnCommand(tTake[take].editor, 40659) -- 删除重叠音符
    
    local events = {}
    local _, MIDI = reaper.MIDI_GetAllEvts(take, "")
    
    noteEvents = {}
    ccEvents = {}
    textEvents = {}
    
    local noteStartEventAtPitch = {} -- 音高对应的当前遍历开始事件
    local articulationEventAtPitch = {}
    
    local pos = 1
    local lastPos = 0
    while pos <= MIDI:len() do
        local offset, flags, msg
        offset, flags, msg, pos = string.unpack("i4Bs4", MIDI, pos)
        local event = { offset = offset, pos = lastPos + offset, flags = flags, msg = msg }
        table.insert(events, event)
        
        local eventType = getEventType(event)
        local eventPitch = getEventPitch(event)
        
        -- print("type:" .. eventType .. " flags:" .. flags .. " offset:" .. offset .. " msg:" .. table.concat(table.pack(string.byte(msg, 1, #msg)), " "))
        if eventType == EVENT_NOTE_START then
            noteStartEventAtPitch[eventPitch] = event
        elseif eventType == EVENT_NOTE_END then
            local start = noteStartEventAtPitch[eventPitch]
            if start == nil then error("音符有重叠無法解析") end
            local noteEvent = {
                first = start,
                second = event,
                articulation = articulationEventAtPitch[eventPitch],
                pitch = getEventPitch(start)
            }
            table.insert(noteEvents, noteEvent)
            -- table.print(noteEvent)
            noteStartEventAtPitch[eventPitch] = nil
            articulationEventAtPitch[eventPitch] = nil
        elseif eventType == EVENT_ARTICULATION then
            if event.msg:byte(1) == 0xFF and not (event.msg:byte(2) == 0x0F) then
                table.insert(textEvents, event)
            elseif event.msg:find("articulation") then
                -- print(event.msg)
                local chan, pitch = getArticulationInfo(event)
                articulationEventAtPitch[tonumber(pitch)] = event
            end
        elseif eventType == 11 then
            if event.msg:byte(2) >= 0 and event.msg:byte(2) <= 127 then
                table.insert(ccEvents, event)
            end
        elseif eventType == 14 then -- 弯音
            table.insert(ccEvents, event)
        end
        lastPos = lastPos + offset
    end

    if toggle == "3" then
        Position(take, gird) -- 只移动音符的起始位置
    elseif toggle == "2" then
        EndTimes(take, gird) -- 结束位置量化，仅音符
    elseif toggle == "1" then
        StartTimes(take, gird) -- 起始位置量化，仅音符
    elseif toggle == "0" then
        StartTimes(take, gird) -- 默认起始位置量化，仅音符
        EndTimes(take, gird) -- 默认结束位置量化，仅音符
        CCEvents(take, gird) -- 默认量化CC事件
        TextEvents(take, gird) -- 默认量化文本事件
    end
    
    setAllEvents(take, events)
    reaper.MIDI_Sort(take)

    if not (sourceLengthTicks == reaper.BR_GetMidiSourceLenPPQ(take)) then
        reaper.MIDI_SetAllEvts(take, MIDI)
        reaper.ShowMessageBox("腳本造成事件位置位移，原始MIDI數據已恢復", "錯誤", 0)
    end
end
reaper.Undo_EndBlock("Quantize (Fast)", -1)
reaper.UpdateArrange()
reaper.SN_FocusMIDIEditor()
