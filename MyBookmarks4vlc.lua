-------------- Global variables -------------
local file = {
    uri = nil,
    name = nil,
    hash = nil,
    dir = nil,
}
local bookmarkFilePath = nil
--local input = nil
local Bookmarks = {}
local selectedBookmarkId = nil
--UI
local dialog_UI = nil
local bookmarks_dialog = {}

local csv_options = {
    import = {
        text = "Import",
        message_text = "Specify the path of the CSV file with the bookmarks you want to import",
        function_ = function()
        end
    },
    export = {
        text = "Export",
        message_text = "Specify the path where you want to save the CSV file containing bookmarks",
        function_ = function()
        end
    },
}
-----------------------------------------------

-- VLC defined callback functions --------------------------------------
-- Script descriptor, called when the extensions are scanned
function descriptor()
    return {
        title = "MyBookmarks4vlc",
        version = "1.0",
        author = "bucchio",
        url = '',
        shortdesc = "MyBookmarks4vlc",
        description = "",
        capabilities = {"menu", "playing-listener"}
    }
end

-- First function to be called when the extension is activated
function activate()
    vlc.msg.dbg("[Activate extension] Welcome! Start saving your favorite moments in your videos permanently!")

    if not check_config() then
        vlc.msg.err("Unsupported VLC version")
        return false
    end

    if vlc.input.item() then
        if getFileHash() then
            bookmarkFilePath = bookmarksDir..slash..file.hash
            Bookmarks = table_load(bookmarkFilePath)
            --load_bookmarks()
        end
        show_main_gui()
    
    else
        show_info_gui()
    end
end

function input_changed()
    vlc.msg.dbg("Input changed")
    collectgarbage()
    --set_interface_main()
    collectgarbage()
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





function getFileInfo(item)
    if not item then
        item = getInputItem()
    end
    
    file.uri = item:uri()
    vlc.msg.dbg("Video URI: " .. file.uri)
    local filePath = vlc.strings.make_path(file.uri)
    if not filePath then
        filePath = vlc.strings.decode_uri(file.uri)
        filePath = string.match(filePath, "^.*[" .. slash .. "]([^" .. slash .. "]-).?[%a%d]*$")
    else
        file.dir, file.name = string.match(filePath, "^(.*[" .. slash .. "])([^" .. slash .. "]-).?[%a%d]*$")
    end
    if not file.name then
        file.name = filePath
    end
    vlc.msg.dbg("media name: "..item:name())
    vlc.msg.dbg("fileName: "..file.name)
    vlc.msg.dbg("filePath: "..file.dir..slash..file.name)
    --file.CleanName = string.gsub(fileName, "[%._]", " ")
    --vlc.msg.dbg("fileCleanName: "..file.CleanName)

    --vlc.msg.dbg("file info: "..(dump_xml(file)))
    
    collectgarbage()
end

function getFileHash()
    -- Calculate file hash

    local item = getInputItem()

    if not item then
        vlc.msg.err("Can't get input item")
      return false
    end

    getFileInfo(item)

    local data_start = ""
    local data_end = ""
    local size
    local chunk_size = 65536
    local ok
    local err

    -- Get data for hash calculation
    vlc.msg.dbg("Read hash data from stream")

    local file_ = vlc.stream(file.uri)

    data_start = file_:read(chunk_size)
    ok, size = pcall(file_.getsize, file_)
    if not size then
        vlc.msg.warn("Failed to get stream size: " .. size)
        return false
    end
    ok, err = pcall(file_.seek, file_, size - chunk_size)
    if not ok then
        vlc.msg.warn("Failed to seek to the end of the stream: " .. err)
        return false
    end
    data_end = file_:read(chunk_size)

    -- Hash calculation
    local lo = size
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

    file.bytesize = size
    file.hash = string.format("%08x%08x", hi, lo)
    vlc.msg.dbg("File hash: " .. file.hash)
    vlc.msg.dbg("bytesize: " .. file.bytesize)
    collectgarbage()
    return true
end


function check_config()
    slash = package.config:sub(1, 1)
    if slash == "\\" then
        os = "win"
    else
        os = "lin"
    end
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
        collectgarbage()
        return true
    end
    
    return false
end


--[[function load_bookmark_file()
    bookmarkFilePath = bookmarksDir..slash..file.hash

    if file_exist(bookmarkFilePath) then
        vlc.msg.dbg("Loading bookmarks file: " .. bookmarkFilePath)
        


    else
        vlc.msg.dbg("No bookmarks for file "..file.name)
    end
end

function create_file(path)
    
end

function load_bookmarks()
    local filePath = bookmarksDir..slash.."data.xml"
    local file = io.open(filePath, "rb")
    if not file then return false end
    local resp = file:read("*all")
    file:flush()
    --bookmarks = parse_xml(resp)
    --vlc.msg.dbg("bookmarks: "..dump_for_debug(bookmarks))
    table.sort(bookmarks, function(a, b)
        return (tonumber(a[2][2][2][2]["time"])) < tonumber(b[2][2][2][2]["time"])
    end)
    vlc.msg.dbg(bookmarks[2][2][2][2])
    collectgarbage()
end]]




function file_exist(name) -- test readability
    if not name or trim(name) == "" then
        return false
    end
    local f = vlc.io.open(name, "r")
    if f ~= nil then
        return true
    else
        return false
    end
end

function trim(str)
    if not str then
        return ""
    end
    return string.gsub(str, "^[\r\n%s]*(.-)[\r\n%s]*$", "%1")
end




--[[function set_interface_main()
    --dialog_UI:hide()
    getFileInfo()
    load_bookmark_file()
    print_bookmarks()
    --dialog_UI:show()
end
]]


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

function show_import_gui()
    close_dlg()
    csv_dialog(csv_options.import)
    collectgarbage() -- ~ !important
end
function show_export_gui()
    close_dlg()
    csv_dialog(csv_options.export)
    collectgarbage() -- ~ !important
end

function info_dialog()
    vlc.msg.dbg("Creating Info dialog")
    dialog_UI = vlc.dialog("Info")
    dialog_UI:add_label("Please open a media file before running this extension")
    -- dialog_UI:show()
end

function csv_dialog(option)
    vlc.msg.dbg("Creating " .. option.text .. " dialog")
    dialog_UI = vlc.dialog(option.text .. " csv")
    message_text = dialog_UI:add_label(option.message_text, 1, 1, 10, 1)

    dialog_UI:add_label("Location : ", 1, 2, 1, 1)
    location_input = dialog_UI:add_text_input(file.dir, 1, 3, 10, 1)

    dialog_UI:add_button(option.text, option.function_, 1, 4, 1, 1)
    dialog_UI:add_button("Cancel", show_main_gui, 2, 4, 1, 1)

    -- dialog_UI:show()
end

function exportBookmarks()

end

function importBookmarks()

end







--[[function parse_xml(data)
    local tree = {}
    local stack = {}
    local tmp = {}
    local level = 0
    local op, tag, p, empty, val
    table.insert(stack, tree)
    local resolve_xml = vlc.strings.resolve_xml_special_chars

    for op, tag, p, empty, val in string.gmatch(data, "[%s\r\n\t]*<(%/?)([%w:_]+)(.-)(%/?)>" ..
        "[%s\r\n\t]*([^<]*)[%s\r\n\t]*") do
        if op == "/" then
            if level > 0 then
                level = level - 1
                table.remove(stack)
            end
        else
            level = level + 1
            if val == "" then
                if type(stack[level][tag]) == "nil" then
                    stack[level][tag] = {}
                    table.insert(stack, stack[level][tag])
                else
                    if type(stack[level][tag][1]) == "nil" then
                        tmp = nil
                        tmp = stack[level][tag]
                        stack[level][tag] = nil
                        stack[level][tag] = {}
                        table.insert(stack[level][tag], tmp)
                    end
                    tmp = nil
                    tmp = {}
                    table.insert(stack[level][tag], tmp)
                    table.insert(stack, tmp)
                end
            else
                if type(stack[level][tag]) == "nil" then
                    stack[level][tag] = {}
                end
                stack[level][tag] = resolve_xml(val)
                table.insert(stack, {})
            end
            if empty ~= "" then
                stack[level][tag] = ""
                level = level - 1
                table.remove(stack)
            end
        end
    end
    collectgarbage()
    return tree
end

function dump_for_debug(o)
    if type(o) == 'table' then
        local s = '{ '
        for k, v in pairs(o) do
            if type(k) ~= 'number' then
                k = '"' .. k .. '"'
            end
            s = s .. '[' .. k .. '] = ' .. dump_for_debug(v) .. ',\n'
        end
        return s .. '} '
    else
        if type(o) ~= 'number' then
            return '"' .. o .. '"'
        else
            return o
        end
    end
end]]




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

function table_binInsert(t, value, fcomp)
    local fcomp_default = function( a,b ) return a < b end
    -- Initialise compare function
    local fcomp = fcomp or fcomp_default
    --  Initialise numbers
    local iStart,iEnd,iMid,iState = 1,#t,1,0
    -- Get insert position
    while iStart <= iEnd do
       -- calculate middle
       iMid = math.floor( (iStart+iEnd)/2 )
       -- compare
       if fcomp( value,t[iMid] ) then
          iEnd,iState = iMid - 1,0
       else
          iStart,iState = iMid + 1,1
       end
    end
    table.insert( t,(iMid+iState),value )
    return (iMid+iState)
 end

 function tablelength(T)
    local count = 0
    for _ in pairs(T) do
        count = count + 1
    end
    return count
end


function getInputItem()
    return vlc.item or vlc.input.item()
end

function getInput()
    return vlc.object.input()
end

function getMediaTime(input)
    return vlc.var.get(input, "time")
end

function getFormattedTime(time)
    local milliseconds = math.floor(time/1000)
    local seconds = math.floor((milliseconds / 1000) % 60)
    local minutes = math.floor((milliseconds / 60000) % 60)
    local hours   = math.floor((milliseconds / 3600000) % 24)
    milliseconds = math.floor(milliseconds % 1000)
    return string.format("%02d:%02d:%02d.%03d",hours,minutes,seconds,milliseconds)
end





-- GUI Setup and buttons callbacks ----------------------------------------
-- Create the main dialog
function main_dialog()
    vlc.msg.dbg("Creating main dialog")
    -- Gui positional args
    -- col, row, col_span, row_span, width, height
    dialog_UI = vlc.dialog("Save your Bookmarks")
    -- rename input box
    dialog_UI:add_button("Add", addBookmark, 3, 1, 1, 1)
    bookmarks_dialog['text_input'] = dialog_UI:add_text_input('Bookmark (' .. (#Bookmarks + 1) .. ')', 2, 1, 1, 1)
    -- buttons
    dialog_UI:add_button("Go", goToBookmark, 1, 2, 1, 1)
    dialog_UI:add_button("Rename", editBookmark, 1, 3, 1, 1)
    dialog_UI:add_button("Remove", removeBookmark, 1, 4, 1, 1)
    dialog_UI:add_button("Close", deactivate, 1, 5, 1, 1)
    -- dialog_UI:add_button("Import csv", show_import_gui, 1, 10, 1, 1)
    -- dialog_UI:add_button("Export csv", show_export_gui, 1, 11, 1, 1)
    -- bookmarks list
    bookmarks_dialog['invisible_label'] = dialog_UI:add_label('', 2, 2, 0, 0)
    bookmarks_dialog['bookmarks_list'] = dialog_UI:add_list(2, 2, 2, 10)
    -- message_label
    bookmarks_dialog['footer_message'] = dialog_UI:add_label("", 2, 12, 2, 1)
    showBookmarks()
    dialog_UI:show()
end

function showBookmarks()
    if bookmarks_dialog['bookmarks_list'] then
        bookmarks_dialog['bookmarks_list']:clear()
        local maxText = ""
        for idx, b in pairs(Bookmarks) do
            local text = '#' .. idx .. ' - ' .. b.formattedTime .. '  -  ' .. b.label
            bookmarks_dialog['bookmarks_list']:add_value(text, idx)
            if string.len(text) > string.len(maxText) then
                maxText = text
            end
        end
        bookmarks_dialog['invisible_label']:set_text(maxText)
        -- bookmarks_dialog['invisible_label']:set_text(string.rep('¢', maxText))
        -- bookmarks_dialog['invisible_label']:set_text(string.rep('ㅤ', #maxText))
    end
end

-----button callback
function addBookmark()
    dlt_footer()

    if bookmarks_dialog['text_input'] then
        local label = bookmarks_dialog['text_input']:get_text()
        if string.len(label) ~= 0 then
            if selectedBookmarkId ~= nil then
                Bookmarks[selectedBookmarkId].label = label
                selectedBookmarkId = nil
            else
                local b = {}
                local input = getInput()
                b.time = getMediaTime(input)
                b.label = label
                -- b.addedDate = os.date("%d/%m/%Y %X")
                b.formattedTime = getFormattedTime(b.time)
                table_binInsert(Bookmarks, b, function(a, b)
                    return a.time < b.time
                end)
            end
            table_save(Bookmarks, bookmarkFilePath)
            bookmarks_dialog['text_input']:set_text('')
            showBookmarks()
        else
            --[[bookmarks_dialog['footer_message'] = dialog_UI:add_label(
                "<p style='margin-left: 8px;'><b>Please enter your bookmark title</b></p>", 2, 12, 2, 1)]]
            bookmarks_dialog['footer_message']:set_text(
                "<p style='margin-left: 8px;'><b>Please enter your bookmark title</b></p>")
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
                    break
                end
            else
                --[[bookmarks_dialog['footer_message'] = dialog_UI:add_label(
                    "<p style='color:red; margin-left: 8px;'><b>Please select only one item</b></p>", 2, 12, 2, 1)]]
                bookmarks_dialog['footer_message']:set_text(
                    "<p style='color:red; margin-left: 8px;'><b>Please select only one item</b></p>")
            end
        else
            --[[bookmarks_dialog['footer_message'] = dialog_UI:add_label(
                "<p style='margin-left: 8px;'><b>Please select a item</b></p>", 2, 12, 2, 1)]]
            bookmarks_dialog['footer_message']:set_text("<p style='margin-left: 8px;'><b>Please select a item</b></p>")

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
                -- vlc.msg.dbg("removing bookmark "..Bookmarks[idx-count].formattedTime..' - '..Bookmarks[idx-count].label)
                table.remove(Bookmarks, idx - count)
                count = count + 1
            end
            table_save(Bookmarks, bookmarkFilePath)
            showBookmarks()
        else
            --[[bookmarks_dialog['footer_message'] = dialog_UI:add_label(
                "<p style='margin-left: 8px;'><b>Please select items you want remove</b></p>", 2, 12, 2, 1)]]
            bookmarks_dialog['footer_message']:set_text(
                "<p style='margin-left: 8px;'><b>Please select items you want remove</b></p>")
        end
    end
end

function goToBookmark()
    dlt_footer()
    local input = getInput()

    if bookmarks_dialog['bookmarks_list'] then
        local selection = bookmarks_dialog['bookmarks_list']:get_selection()
        if next(selection) then
            if tablelength(selection) == 1 then
                for idx, _ in pairs(selection) do
                    vlc.var.set(input, "time", Bookmarks[idx].time)
                    break
                end
            else
                --[[bookmarks_dialog['footer_message'] = dialog_UI:add_label(
                    "<p style='color:red; margin-left: 8px;'><b>Please select only one item</b></p>", 2, 12, 2, 1)]]
                bookmarks_dialog['footer_message']:set_text(
                    "<p style='color:red; margin-left: 8px;'><b>Please select only one item</b></p>")

            end
        else
            --[[bookmarks_dialog['footer_message'] = dialog_UI:add_label(
                "<p style='margin-left: 8px;'><b>Please select a item</b></p>", 2, 12, 2, 1)]]
            bookmarks_dialog['footer_message']:set_text("<p style='margin-left: 8px;'><b>Please select a item</b></p>")
        end
    end
end

function dlt_footer()
    if bookmarks_dialog['footer_message'] then
        bookmarks_dialog['footer_message']:set_text('')
        --[[dialog_UI:del_widget(bookmarks_dialog['footer_message'])
        bookmarks_dialog['footer_message'] = nil
        collectgarbage()]]
    end
end

-- End GUI Setup and buttons callbacks -------------------------------------











--[[function getSelectedItem()
    dlt_top_box()
    local selection = bookmarks_dialog['list']:get_selection()
    --vlc.msg.dbg(dump_for_debug(selection))
    if next(selection) then
        if tablelength(selection) > 1 then
            bottom_message = dialog_UI:add_label("<p style='color:red; margin-left: 8px;'><b>Please select only one item</b></p>", 2,12,2,1)
            return
        end
        for idx, _ in pairs(selection) do
            --vlc.msg.dbg("selected idx = " .. idx)
            return idx
        end
    else
        bottom_message = dialog_UI:add_label("<p style='margin-left: 8px;'><b>Please select a item</b></p>", 2,12,2,1)
    end
end

function addBookmark()
    dlt_top_box()
    local b = {}
    local input = getInput()
    b.time = getMediaTime(input)
    b.label = file.name..' ('..#Bookmarks..')'
    --b.addedDate = os.date("%d/%m/%Y %X")
    b.formattedTime = getFormattedTime(b.time)
    table_bininsert(Bookmarks, b, function(a, b)
        return a.time < b.time
    end)
    table_save(Bookmarks, bookmarkFilePath)
    showBookmarks()
end

function confirm_caption()
    local new_label = bookmarks_dialog['rename_input']:get_text()
    if string.len(new_label) ~= 0 then
        Bookmarks[idx].label = new_label
        showBookmarks()
    end
    -- new_label = string.gsub(new_label,'[#]%d+','')
    vlc.msg.dbg(Bookmarks[idx].label)
end]]

--[[function dlt_top_box()
    if next(top_box) then
        for id, _ in pairs(top_box) do
            vlc.msg.dbg(id)
            dialog_UI:del_widget(top_box[id])
        end
        top_box = nil
        top_box = {}
        collectgarbage()
    end
end]]