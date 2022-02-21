-------------- Global variables ---------------------------------------
local mediaFile = {}
local input = nil
local Bookmarks = {}
local selectedBookmarkId = nil
local bookmarkFilePath = nil
-- UI
local dialog_UI = nil
local bookmarks_dialog = {}
------------------------------------------------------------------------

-- VLC defined callback functions --------------------------------------
-- Script descriptor, called when the extensions are scanned
function descriptor()
    return {
        title = "Permanents Bookmarks",
        version = "0.1",
        author = "bucchio",
        url = 'https://github.com/JacopoBucchioni/vlc-permanents-bookmarks',
        shortdesc = "Bookmarks",
        description = "Save bookmarks for your media files and store them permanently.",
        capabilities = {"menu", "input-listener"}
    }
end

-- First function to be called when the extension is activated
function activate()
    vlc.msg.dbg("[Activate extension] Welcome! Start saving your bookmarks!")
    local ok, err = pcall(check_config)
    if not ok then
        vlc.msg.err(err)
        return false
    end

    input = vlc.object.input()
    if input then
        load_bookmarks()
        show_main_gui()
    else
        show_info_gui()
    end
end

-- related to capabilities={"input-listener"} in descriptor()
-- triggered by Start/Stop media input event
function input_changed()
    vlc.msg.dbg("[Input changed]")
    input = vlc.object.input()
    if input then
        load_bookmarks()
        --[[if dialog_UI then
            showBookmarks()
            dialog_UI:show()
        end]]
        show_main_gui()

    else
        close_dlg()
        mediaFile = nil
        mediaFile = {}
        Bookmarks = nil
        Bookmarks = {}
        selectedBookmarkId = nil
        bookmarkFilePath = nil
    end
    collectgarbage()
end

-- triggered by available media input meta data?
function meta_changed()
end

-- Called when the extension dialog is close
function close()
    vlc.deactivate()
end

-- Called when the extension is deactivated
function deactivate()
    vlc.msg.dbg("[Deactivate extension] Bye bye!")
    if dialog_UI then
        dialog_UI:hide()
    end
end

-- Called on mouseover on the extension in View menu
function menu()
    return {"Show dialog"}
end

-- trigger function on menu() function call
function trigger_menu(dlg_id)
    show_main_gui()
end
-- End VLC defined callback functions ----------------------------------

-- // Bookmarks init function
function load_bookmarks()
    mediaFile.title = vlc.input.item():name()
    mediaFile.uri = vlc.input.item():uri()
    if mediaFile.uri then
        local filePath = vlc.strings.make_path(mediaFile.uri)
        if not filePath then
            filePath = vlc.strings.decode_uri(mediaFile.uri)
            local match = string.match(filePath, "^.*[" .. slash .. "]([^" .. slash .. "]-).?[%a%d]*$")
            if match then
                filePath = match
            end
        else
            mediaFile.dir, mediaFile.name = string.match(filePath,
                "^(.*[" .. slash .. "])([^" .. slash .. "]-).?[%a%d]*$")
        end
        if not mediaFile.name then
            mediaFile.name = filePath
        end
        vlc.msg.dbg("Video Meta Title: " .. mediaFile.title)
        vlc.msg.dbg("Video URI: " .. mediaFile.uri)
        vlc.msg.dbg("fileName: " .. mediaFile.name)
        vlc.msg.dbg("fileDir: " .. tostring(mediaFile.dir))

        getFileHash()
        if mediaFile.hash then
            bookmarkFilePath = bookmarksDir .. slash .. mediaFile.hash
            Bookmarks = table_load(bookmarkFilePath)
        end
    end
    collectgarbage()
end

function getFileHash()
    -- Calculate media hash
    local data_start = ""
    local data_end = ""
    local chunk_size = 65536
    local size
    local ok
    local err

    -- Get data for hash calculation
    vlc.msg.dbg("init Read hash data from stream")

    local stream = vlc.stream(mediaFile.uri)
    data_start = stream:read(chunk_size)
    ok, size = pcall(stream.getsize, stream)
    if not size then
        vlc.msg.warn("Failed to get stream size: " .. size)
        return false
    end
    mediaFile.bytesize = size
    vlc.msg.dbg("File bytesize: " .. mediaFile.bytesize)

    size = math.floor(size / 2)
    ok, err = pcall(stream.seek, stream, size - chunk_size)
    if not ok then
        vlc.msg.warn("Failed to seek to the middle of the stream: " .. err)
        return false
    end
    -- data_start = stream:read(chunk_size)
    data_end = stream:read(chunk_size)
    vlc.msg.dbg("finish Read hash data from stream")
    -- stream = nil

    -- Hash calculation
    local lo = mediaFile.bytesize
    -- local lo = size
    local hi = 0
    local o, a, b, c, d, e, f, g, h
    local hash_data = data_start .. data_end
    local max_size = 4294967296
    local overflow

    for i = 1, #hash_data, 8 do
        a, b, c, d, e, f, g, h = hash_data:byte(i, i + 7)
        lo = lo + a + b * 256 + c * 65536 + d * 16777216
        hi = hi + e + f * 256 + g * 65536 + h * 16777216

        if lo > max_size then
            overflow = math.floor(lo / max_size)
            lo = lo - (overflow * max_size)
            hi = hi + overflow
        end

        if hi > max_size then
            overflow = math.floor(hi / max_size)
            hi = hi - (overflow * max_size)
        end
    end

    mediaFile.hash = string.format("%08x%08x", hi, lo)
    vlc.msg.dbg("File hash: " .. mediaFile.hash)
    collectgarbage()
    -- return true
end

-- // system check and extension config
function check_config()
    slash = package.config:sub(1, 1)
    --[[if slash == "\\" then
        os = "win"
    else
        os = "lin"
    end]]
    bookmarksDir = vlc.config.userdatadir()
    local res, err = vlc.io.mkdir(bookmarksDir, "0700")
    if res ~= 0 and err ~= vlc.errno.EEXIST then
        vlc.msg.warn("Failed to create " .. bookmarksDir)
        return false
    end
    local subdirs = {"lua", "extensions", "userdata", "bookmarks"}
    for _, dir in ipairs(subdirs) do
        res, err = vlc.io.mkdir(bookmarksDir .. slash .. dir, "0700")
        if res ~= 0 and err ~= vlc.errno.EEXIST then
            vlc.msg.warn("Failed to create " .. bookmarksDir .. slash .. dir)
            return false
        end
        bookmarksDir = bookmarksDir .. slash .. dir
    end

    if bookmarksDir then
        vlc.msg.dbg("Bookmarks directory: " .. bookmarksDir)
        -- return true
    end
    collectgarbage()
    -- return true
end

-- // The Save Function
function table_save(tbl, filename)
    local function exportstring(s)
        return string.format("%q", s)
    end

    local charS, charE = "   ", "\n"
    local file, err = io.open(filename, "wb")
    if err then
        return err
    end

    -- initiate variables for save procedure
    local tables, lookup = {tbl}, {
        [tbl] = 1
    }
    file:write("return {" .. charE)

    for idx, t in ipairs(tables) do
        file:write("-- Table: {" .. idx .. "}" .. charE)
        file:write("{" .. charE)
        local thandled = {}

        for i, v in ipairs(t) do
            thandled[i] = true
            local stype = type(v)
            -- only handle value
            if stype == "table" then
                if not lookup[v] then
                    table.insert(tables, v)
                    lookup[v] = #tables
                end
                file:write(charS .. "{" .. lookup[v] .. "}," .. charE)
            elseif stype == "string" then
                file:write(charS .. exportstring(v) .. "," .. charE)
            elseif stype == "number" then
                file:write(charS .. tostring(v) .. "," .. charE)
            end
        end

        for i, v in pairs(t) do
            -- escape handled values
            if (not thandled[i]) then

                local str = ""
                local stype = type(i)
                -- handle index
                if stype == "table" then
                    if not lookup[i] then
                        table.insert(tables, i)
                        lookup[i] = #tables
                    end
                    str = charS .. "[{" .. lookup[i] .. "}]="
                elseif stype == "string" then
                    str = charS .. "[" .. exportstring(i) .. "]="
                elseif stype == "number" then
                    str = charS .. "[" .. tostring(i) .. "]="
                end

                if str ~= "" then
                    stype = type(v)
                    -- handle value
                    if stype == "table" then
                        if not lookup[v] then
                            table.insert(tables, v)
                            lookup[v] = #tables
                        end
                        file:write(str .. "{" .. lookup[v] .. "}," .. charE)
                    elseif stype == "string" then
                        file:write(str .. exportstring(v) .. "," .. charE)
                    elseif stype == "number" then
                        file:write(str .. tostring(v) .. "," .. charE)
                    end
                end
            end
        end
        file:write("}," .. charE)
    end
    file:write("}")
    file:close()
end

-- // The Load Function
function table_load(sfile)
    local ftables, err = loadfile(sfile)
    if err then
        return {}, err
    end
    local tables = ftables()
    for idx = 1, #tables do
        local tolinki = {}
        for i, v in pairs(tables[idx]) do
            if type(v) == "table" then
                tables[idx][i] = tables[v[1]]
            end
            if type(i) == "table" and tables[i[1]] then
                table.insert(tolinki, {i, tables[i[1]]})
            end
        end
        -- link indices
        for _, v in ipairs(tolinki) do
            tables[idx][v[2]], tables[idx][v[1]] = tables[idx][v[1]], nil
        end
    end
    return tables[1]
end

-- // The Binary Insert Function
function table_binInsert(t, value, fcomp)
    local fcomp_default = function(a, b)
        return a < b
    end
    -- Initialise compare function
    local fcomp = fcomp or fcomp_default
    --  Initialise numbers
    local iStart, iEnd, iMid, iState = 1, #t, 1, 0
    -- Get insert position
    while iStart <= iEnd do
        -- calculate middle
        iMid = math.floor((iStart + iEnd) / 2)
        -- compare
        if fcomp(value, t[iMid]) then
            iEnd, iState = iMid - 1, 0
        else
            iStart, iState = iMid + 1, 1
        end
    end
    -- table.insert( t,(iMid+iState),value )
    return (iMid + iState)
end

function tablelength(T)
    local count = 0
    for _ in pairs(T) do
        count = count + 1
    end
    return count
end

-- // get number rappresenting time in microseconds and return a string with formatted time hh:mm:ss.millis
function getFormattedTime(time)
    local milliseconds = math.floor(time / 1000)
    local seconds = math.floor((milliseconds / 1000) % 60)
    local minutes = math.floor((milliseconds / 60000) % 60)
    local hours = math.floor((milliseconds / 3600000) % 24)
    milliseconds = math.floor(milliseconds % 1000)
    return string.format("%02d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
end

-- GUI Setup and buttons callbacks ----------------------------------------
-- Create the main dialog
function main_dialog()
    vlc.msg.dbg("Creating main dialog")
    -- Gui positional args
    -- col, row, col_span, row_span, width, height
    dialog_UI = vlc.dialog("Save your Bookmarks")
    -- rename input box
    dialog_UI:add_button("Add", addBookmark, 1, 1, 1, 1)
    bookmarks_dialog['text_input'] = dialog_UI:add_text_input('Bookmark (' .. (#Bookmarks + 1) .. ')', 2, 1, 1, 1)
    -- buttons
    dialog_UI:add_button("Go", goToBookmark, 1, 2, 1, 1)
    dialog_UI:add_button("Rename", editBookmark, 1, 3, 1, 1)
    dialog_UI:add_button("Remove", removeBookmark, 1, 4, 1, 1)
    dialog_UI:add_button("Close", deactivate, 1, 5, 1, 1)
    -- dialog_UI:add_button("Import csv", show_import_gui, 1, 10, 1, 1)
    -- dialog_UI:add_button("Export csv", show_export_gui, 1, 11, 1, 1)
    -- bookmarks list
    bookmarks_dialog['invisible_label'] = dialog_UI:add_label('', 2, 2, 0, 0) -- ~ !important: invisible_label BEFORE bookmarks_list
    bookmarks_dialog['bookmarks_list'] = dialog_UI:add_list(2, 2, 1, 14)
    -- message_label
    bookmarks_dialog['footer_message'] = dialog_UI:add_label('', 2, 16, 1, 1)
    showBookmarks()
    dialog_UI:show()
end

function showBookmarks()
    if bookmarks_dialog['bookmarks_list'] then
        bookmarks_dialog['bookmarks_list']:clear()
        local maxText = ''
        local count = 0
        for idx, b in pairs(Bookmarks) do
            local text = '#' .. idx .. ' - ' .. b.formattedTime .. 'ㅤ-ㅤ' .. b.label
            bookmarks_dialog['bookmarks_list']:add_value(text, idx)

            -- for dialog width autofit
            if #text > #maxText then
                maxText = text
            end
            text = idx .. b.label
            if #text > count then
                count = #text
            end
        end
        count = math.ceil(count * 8.5) + 143 -- works :)
        if count < 480 then -- max dialog width = 480px
            bookmarks_dialog['invisible_label']:set_text("<p style='font-size: 15px; margin-left: 24px;'>" .. maxText ..
                                                             "</p>")
        else
            bookmarks_dialog['invisible_label']:set_text("<p style='font-size: 15px; margin-left: 480px;'>.</p>")
        end

        bookmarks_dialog['text_input']:set_text('Bookmark (' .. (#Bookmarks + 1) .. ')')
    end
end

-- Buttons callbacks -------------------------------------------------------------
function addBookmark()
    dlt_footer()
    if bookmarks_dialog['text_input'] then
        local label = bookmarks_dialog['text_input']:get_text()
        if string.len(label) > 0 then
            if selectedBookmarkId ~= nil then
                Bookmarks[selectedBookmarkId].label = label
                selectedBookmarkId = nil
            else
                local b = {}
                b.time = vlc.var.get(input, "time")
                b.label = label
                -- b.addedDate = os.date("%d/%m/%Y %X")
                b.formattedTime = getFormattedTime(b.time)
                local i = table_binInsert(Bookmarks, b, function(a, b)
                    return a.time <= b.time
                end)

                if Bookmarks[i] then
                    if Bookmarks[i].formattedTime == b.formattedTime then
                        bookmarks_dialog['footer_message']:set_text(setMessageStyle("Bookmark already added"))
                        return
                    end
                end
                table.insert(Bookmarks, i, b)
            end
            table_save(Bookmarks, bookmarkFilePath)
            bookmarks_dialog['text_input']:set_text('')
            showBookmarks()
        else
            bookmarks_dialog['footer_message']:set_text(setMessageStyle("Please enter your bookmark title"))
        end
    end
end

function goToBookmark()
    dlt_footer()
    if bookmarks_dialog['bookmarks_list'] then
        local selection = bookmarks_dialog['bookmarks_list']:get_selection()
        if next(selection) then
            if tablelength(selection) == 1 then
                for idx, _ in pairs(selection) do
                    vlc.var.set(input, "time", Bookmarks[idx].time)
                    break
                end
            else
                bookmarks_dialog['footer_message']:set_text(setMessageStyle("Please select only one item"))
            end
        else
            bookmarks_dialog['footer_message']:set_text(setMessageStyle("Please select a item"))
        end
    end
end

function editBookmark()
    dlt_footer()
    if bookmarks_dialog['bookmarks_list'] then
        local selection = bookmarks_dialog['bookmarks_list']:get_selection()
        if next(selection) then
            if tablelength(selection) == 1 then
                for idx, _ in pairs(selection) do
                    bookmarks_dialog['text_input']:set_text(Bookmarks[idx].label)
                    selectedBookmarkId = idx
                    -- break
                    return
                end
            else
                bookmarks_dialog['footer_message']:set_text(setMessageStyle("Please select only one item"))
            end
        else
            bookmarks_dialog['footer_message']:set_text(setMessageStyle("Please select a item"))
        end
    end
end

function removeBookmark()
    dlt_footer()
    if bookmarks_dialog['bookmarks_list'] then
        local selection = bookmarks_dialog['bookmarks_list']:get_selection()
        if next(selection) then
            local count = 0
            for idx, _ in pairs(selection) do
                table.remove(Bookmarks, idx - count)
                count = count + 1
            end
            table_save(Bookmarks, bookmarkFilePath)
            showBookmarks()
        else
            bookmarks_dialog['footer_message']:set_text(setMessageStyle("Please select items you want remove"))
        end
    end
end
-- End buttons callbacks -------------------------------------------------

function dlt_footer()
    if bookmarks_dialog['footer_message'] then
        bookmarks_dialog['footer_message']:set_text('')
        --[[dialog_UI:del_widget(bookmarks_dialog['footer_message'])
        bookmarks_dialog['footer_message'] = nil
        collectgarbage()]]
    end
end

function setMessageStyle(str)
    return "<p style='font-size: 15px; margin-left: 8px;'>" .. str .. "</p>"
end

function close_dlg()
    vlc.msg.dbg("Closing dialog")
    if dialog_UI ~= nil then
        -- dialog_UI:delete() -- Throw an error
        dialog_UI:hide()
    end
    dialog_UI = nil
    bookmarks_dialog = nil
    bookmarks_dialog = {}
    collectgarbage() -- ~ !important
end

function show_main_gui()
    close_dlg()
    main_dialog()
    collectgarbage() -- ~ !important
end

function show_info_gui()
    close_dlg()
    info_dialog()
    collectgarbage() -- ~ !important
end

function info_dialog()
    vlc.msg.dbg("Creating Info dialog")
    dialog_UI = vlc.dialog("Warning")
    dialog_UI:add_label(setMessageStyle("Please open a media file before running this extension"))
    -- dialog_UI:show()
end
-- End GUI Setup ------------------------------------------------------------