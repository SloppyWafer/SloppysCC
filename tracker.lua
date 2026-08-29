-- tracker_gui.lua (v2.8.0)
-- CC:Tweaked Fleet Control GUI with Chunk Strip & Custom Range Chosen Chunk Mining

local PROTOCOL = "turtle_tracker"

local modem = peripheral.find("modem")
if not modem then error("Wireless Modem required on Master Computer!") end
rednet.open(peripheral.getName(modem))

local state = {
    turtles = {},
    sortModes = {"ID", "Name", "Status"},
    currentSortMode = 1,
    viewMode = "table",
    selectedID = nil,
    scrollOffset = 0
}

-- Window Dialog States
local modal = { width = 48, height = 16, x = nil, y = nil, isDragging = false, dragOffsetX = 0, dragOffsetY = 0 }
local apps = { isOpen = false, width = 36, height = 13, x = nil, y = nil, isDragging = false, dragOffsetX = 0, dragOffsetY = 0 }
local oreModal = { isOpen = false, width = 44, height = 18, x = nil, y = nil, isDragging = false, dragOffsetX = 0, dragOffsetY = 0, subPage = "menu", topY = "48", bottomY = "-58", activeField = "topY", strategy = "ore" }
local drive = { isDriving = false, width = 40, height = 11, x = nil, y = nil, isDragging = false, dragOffsetX = 0, dragOffsetY = 0 }
local rename = { isRenaming = false, buffer = "", width = 34, height = 8, x = nil, y = nil, isDragging = false, dragOffsetX = 0, dragOffsetY = 0 }
local telnet = { isConnected = false, buffer = {}, input = "", width = 46, height = 14, x = nil, y = nil, isDragging = false, dragOffsetX = 0, dragOffsetY = 0 }
local update = { isUpdating = false, msg = "", success = nil, width = 38, height = 7, x = nil, y = nil, isDragging = false, dragOffsetX = 0, dragOffsetY = 0 }

local uiColors = {
    BG_COLOR = colors.gray,
    HEADER_BG = colors.blue,
    HEADER_TEXT = colors.white,
    MODAL_BG = colors.lightGray,
    MODAL_TITLE_BG = colors.blue
}

local function closeApps()
    apps.isOpen = false
    apps.isDragging = false
    apps.x, apps.y = nil, nil
end

local function closeOreModal()
    oreModal.isOpen = false
    oreModal.isDragging = false
    oreModal.x, oreModal.y = nil, nil
    oreModal.subPage = "menu"
end

local function closeTelnet()
    telnet.isConnected = false
    telnet.buffer = {}
    telnet.input = ""
    telnet.isDragging = false
    telnet.x, telnet.y = nil, nil
end

local function cancelRename()
    rename.isRenaming = false
    rename.buffer = ""
    rename.isDragging = false
    rename.x, rename.y = nil, nil
end

local function getSortedTurtles()
    local list = {}
    local now = os.epoch("utc")
    for id, data in pairs(state.turtles) do
        data.online = (now - (data.timestamp or 0)) < 8000
        table.insert(list, data)
    end
    table.sort(list, function(a, b)
        if state.currentSortMode == 1 then return a.id < b.id
        elseif state.currentSortMode == 2 then return (a.name or ""):lower() < (b.name or ""):lower()
        elseif state.currentSortMode == 3 then return (a.status or ""):lower() < (b.status or ""):lower()
        end
        return a.id < b.id
    end)
    return list
end

local function drawText(x, y, text, fg, bg)
    if fg then term.setTextColor(fg) end
    if bg then term.setBackgroundColor(bg) end
    term.setCursorPos(x, y)
    term.write(text)
end

local function drawStatusBadge(x, y, status, isOnline)
    if not isOnline then
        drawText(x, y, " Offline  ", colors.white, colors.gray)
        return
    end
    local st = status or "Idle"
    local bg, fg = colors.lime, colors.black
    if st == "Idle" or st == "At Home" then 
        bg = colors.lime
    elseif st:find("Low Fuel") or st == "Error" or st:find("Outdated") then 
        bg = colors.red 
        fg = colors.white
    elseif st:find("Home") or st == "Manual" or st:find("Deposit") then 
        bg = colors.orange 
        fg = colors.black
    elseif st:find("Mining") or st:find("Navigating") or st:find("Strip") or st:find("Clear") or st:find("Birch") or st:find("Farming") then 
        bg = colors.yellow 
        fg = colors.black
    else 
        bg = colors.yellow 
    end
    drawText(x, y, (" " .. st .. "              "):sub(1, 12), fg, bg)
end

local function ensureModalPos(w, h)
    if not modal.x or not modal.y then modal.x = math.floor((w - modal.width) / 2) + 1 modal.y = math.floor((h - modal.height) / 2) + 1 end
    modal.x = math.max(1, math.min(modal.x, w - modal.width + 1))
    modal.y = math.max(1, math.min(modal.y, h - modal.height + 1))
end

local function ensureAppsPos(w, h)
    if not apps.x or not apps.y then apps.x = math.floor((w - apps.width) / 2) + 1 apps.y = math.floor((h - apps.height) / 2) + 1 end
    apps.x = math.max(1, math.min(apps.x, w - apps.width + 1))
    apps.y = math.max(1, math.min(apps.y, h - apps.height + 1))
end

local function ensureOrePos(w, h)
    if not oreModal.x or not oreModal.y then oreModal.x = math.floor((w - oreModal.width) / 2) + 1 oreModal.y = math.floor((h - oreModal.height) / 2) + 1 end
    oreModal.x = math.max(1, math.min(oreModal.x, w - oreModal.width + 1))
    oreModal.y = math.max(1, math.min(oreModal.y, h - oreModal.height + 1))
end

local function ensureDrivePos(w, h)
    if not drive.x or not drive.y then drive.x = math.floor((w - drive.width) / 2) + 1 drive.y = math.floor((h - drive.height) / 2) + 1 end
    drive.x = math.max(1, math.min(drive.x, w - drive.width + 1))
    drive.y = math.max(1, math.min(drive.y, h - drive.height + 1))
end

local function ensureRenamePos(w, h)
    if not rename.x or not rename.y then rename.x = math.floor((w - rename.width) / 2) + 1 rename.y = math.floor((h - rename.height) / 2) + 1 end
    rename.x = math.max(1, math.min(rename.x, w - rename.width + 1))
    rename.y = math.max(1, math.min(rename.y, h - rename.height + 1))
end

local function ensureTelnetPos(w, h)
    if not telnet.x or not telnet.y then telnet.x = math.floor((w - telnet.width) / 2) + 1 telnet.y = math.floor((h - telnet.height) / 2) + 1 end
    telnet.x = math.max(1, math.min(telnet.x, w - telnet.width + 1))
    telnet.y = math.max(1, math.min(telnet.y, h - telnet.height + 1))
end

local function ensureUpdatePos(w, h)
    if not update.x or not update.y then update.x = math.floor((w - update.width) / 2) + 1 update.y = math.floor((h - update.height) / 2) + 1 end
    update.x = math.max(1, math.min(update.x, w - update.width + 1))
    update.y = math.max(1, math.min(update.y, h - update.height + 1))
end

local function getMapPlottedTurtles(w, h)
    local plotted = {}
    local sorted = getSortedTurtles()
    local mapCenterX, mapCenterY = math.floor(w / 2), math.floor((h - 1) / 2) + 1
    local focus = state.turtles[state.selectedID] or sorted[1]
    for _, t in ipairs(sorted) do
        if t.x and t.z then
            local relX = focus and focus.x and (t.x - focus.x) or t.x
            local relZ = focus and focus.z and (t.z - focus.z) or t.z
            local drawX, drawY = mapCenterX + relX, mapCenterY + relZ
            if drawX >= 1 and drawX <= w and drawY >= 2 and drawY <= h then
                table.insert(plotted, { id = t.id, x = drawX, y = drawY, data = t })
            end
        end
    end
    return plotted
end

local function triggerReturnHome()
    if state.selectedID then
        rednet.send(state.selectedID, { type = "go_home" }, PROTOCOL)
        if state.turtles[state.selectedID] then state.turtles[state.selectedID].status = "Returning Home" end
    end
end

local function triggerSetHome()
    if state.selectedID then rednet.send(state.selectedID, { type = "set_home" }, PROTOCOL) end
end

local function sendMiningCommand(data)
    if state.selectedID then
        local payload = { type = "start_mining" }
        if type(data) == "string" then
            payload.mode = data
        elseif type(data) == "table" then
            payload.mode = data.mode
            payload.topY = data.topY
            payload.bottomY = data.bottomY
            payload.strategy = data.strategy
        end
        rednet.send(state.selectedID, payload, PROTOCOL)
        if state.turtles[state.selectedID] then 
            state.turtles[state.selectedID].status = "Mining (" .. (payload.mode or "Chunk") .. ")" 
        end
    end
end

local function getClientCode()
    local path = fs.exists("Turtle_Client") and "Turtle_Client" or "Turtle_Client.lua"
    if not fs.exists(path) then return nil, "File 'Turtle_Client' missing on Master!" end
    local file = fs.open(path, "r")
    if not file then return nil, "Failed to open 'Turtle_Client'" end
    local code = file.readAll()
    file.close()
    return code, nil
end

local function getStoredClientVersion()
    local code = getClientCode()
    if code then
        return code:match('CLIENT_VERSION%s*=%s*["\']([^"\']+)["\']')
    end
    return nil
end

local function triggerTurtleUpdate()
    if not state.selectedID then return end
    local code, err = getClientCode()
    update.isUpdating = true
    update.x, update.y = nil, nil
    if not code then
        update.success = false
        update.msg = err
    else
        update.success = nil
        update.msg = "Sending update to Turtle #" .. state.selectedID .. "..."
        rednet.send(state.selectedID, { type = "update_client", code = code }, PROTOCOL)
    end
end

local function triggerMassUpdate()
    local code, err = getClientCode()
    update.isUpdating = true
    update.x, update.y = nil, nil
    if not code then
        update.success = false
        update.msg = err
    else
        local count = 0
        for id, _ in pairs(state.turtles) do
            rednet.send(id, { type = "update_client", code = code }, PROTOCOL)
            count = count + 1
        end
        update.success = true
        update.msg = "Sent update to " .. count .. " turtle(s)!"
    end
end

local function drawMapView(w, h)
    term.setBackgroundColor(colors.black) term.clear()
    term.setBackgroundColor(uiColors.HEADER_BG) term.setCursorPos(1, 1) term.clearLine()
    drawText(2, 1, "2D SPATIAL MAP VIEW", uiColors.HEADER_TEXT, uiColors.HEADER_BG)
    drawText(w - 18, 1, "[ TABLE ]", colors.yellow, uiColors.HEADER_BG)
    drawText(w - 9, 1, "[ UPDATE ]", colors.white, colors.purple)

    local mapCenterX, mapCenterY = math.floor(w / 2), math.floor((h - 1) / 2) + 1
    for x = 1, w do drawText(x, mapCenterY, "-", colors.gray, colors.black) end
    for y = 2, h do drawText(mapCenterX, y, "|", colors.gray, colors.black) end
    drawText(mapCenterX, mapCenterY, "+", colors.lightGray, colors.black)

    for _, p in ipairs(getMapPlottedTurtles(w, h)) do
        local t = p.data
        local icon = ({ [ "North" ] = "^", [ "South" ] = "v", [ "East" ] = ">", [ "West" ] = "<" })[t.facingName] or "#"
        local fg = t.online and (t.id == state.selectedID and colors.yellow or colors.lime) or colors.red
        drawText(p.x, p.y, icon, fg, colors.black)
    end
    drawText(2, h, "Center: " .. (state.selectedID and ("#" .. state.selectedID) or "Origin (0,0)"), colors.gray, colors.black)
end

local function drawUI()
    local w, h = term.getSize()
    if state.viewMode == "map" then drawMapView(w, h)
    else
        term.setBackgroundColor(uiColors.BG_COLOR) term.clear()
        local sorted = getSortedTurtles()
        term.setBackgroundColor(uiColors.HEADER_BG) term.setCursorPos(1, 1) term.clearLine()
        drawText(2, 1, "FLEET TRACKER (" .. #sorted .. ")", uiColors.HEADER_TEXT, uiColors.HEADER_BG)
        drawText(w - 28, 1, "[ Sort: " .. state.sortModes[state.currentSortMode] .. " ]", colors.yellow, uiColors.HEADER_BG)
        drawText(w - 17, 1, "[ MAP ]", colors.cyan, uiColors.HEADER_BG)
        drawText(w - 9, 1, "[ UPDATE ]", colors.white, colors.purple)

        term.setBackgroundColor(colors.gray) term.setCursorPos(1, 2) term.clearLine()
        drawText(1, 2, string.format(" %-6s %-15s %-12s %-6s %s", "ID", "NAME", "STATUS", "FUEL", "DIR"), colors.yellow, colors.gray)

        for i = 1, h - 2 do
            local index, y = i + state.scrollOffset, i + 2
            if index <= #sorted then
                local t = sorted[index]
                local rowBg = (i % 2 == 0) and colors.gray or colors.lightGray
                local textFg = (rowBg == colors.gray) and colors.white or colors.black
                term.setBackgroundColor(rowBg) term.setCursorPos(1, y) term.clearLine()
                drawText(2, y, string.format("%-6d %-15s", t.id, (t.name or "Turtle"):sub(1, 14)), textFg, rowBg)
                drawStatusBadge(25, y, t.status, t.online)
                local fuelText = (t.fuel and t.maxFuel and t.maxFuel > 0) and string.format("%.1f%%", (t.fuel / t.maxFuel) * 100) or "N/A"
                drawText(37, y, string.format("%-6s", fuelText), textFg, rowBg)
                drawText(44, y, (t.facingName or "N/A"):sub(1, 5), textFg, rowBg)
            end
        end
    end

    -- Main Turtle Info Modal
    if state.selectedID and state.turtles[state.selectedID] then
        ensureModalPos(w, h)
        local t = state.turtles[state.selectedID]
        term.setBackgroundColor(colors.black)
        for row = modal.y + 1, modal.y + modal.height do term.setCursorPos(modal.x + 1, row) term.write(string.rep(" ", modal.width)) end
        term.setBackgroundColor(uiColors.MODAL_BG)
        for row = modal.y, modal.y + modal.height - 1 do term.setCursorPos(modal.x, row) term.write(string.rep(" ", modal.width)) end
        drawText(modal.x, modal.y, string.rep(" ", modal.width), colors.white, uiColors.MODAL_TITLE_BG)
        drawText(modal.x + 1, modal.y, "INFO: " .. (t.name or "Turtle"):sub(1, modal.width - 7), colors.white, uiColors.MODAL_TITLE_BG)
        drawText(modal.x + modal.width - 4, modal.y, " [X] ", colors.lightGray, colors.red)

        local line = modal.y + 2
        drawText(modal.x + 3, line, "ID:", colors.black, uiColors.MODAL_BG) drawText(modal.x + 15, line, tostring(t.id), colors.blue, uiColors.MODAL_BG) line = line + 1
        drawText(modal.x + 3, line, "Status:", colors.black, uiColors.MODAL_BG) drawText(modal.x + 15, line, tostring(t.status or "Unknown"), colors.black, uiColors.MODAL_BG) line = line + 1
        drawText(modal.x + 3, line, "Fuel:", colors.black, uiColors.MODAL_BG) drawText(modal.x + 15, line, (t.fuel and t.maxFuel) and string.format("%.1f / %.1f", t.fuel, t.maxFuel) or "Unknown", colors.black, uiColors.MODAL_BG) line = line + 1
        drawText(modal.x + 3, line, "Position:", colors.black, uiColors.MODAL_BG) drawText(modal.x + 15, line, (t.x and t.y and t.z) and (t.x .. ", " .. t.y .. ", " .. t.z) or "No GPS", colors.black, uiColors.MODAL_BG) line = line + 1
        drawText(modal.x + 3, line, "Heading:", colors.black, uiColors.MODAL_BG) drawText(modal.x + 15, line, tostring(t.facingName or "Unknown"), colors.black, uiColors.MODAL_BG) line = line + 1
        drawText(modal.x + 3, line, "Inventory:", colors.black, uiColors.MODAL_BG) drawText(modal.x + 15, line, (t.freeSlots and t.freeSlots .. " free slots") or "Unknown", colors.black, uiColors.MODAL_BG) line = line + 1
        drawText(modal.x + 3, line, "Home Pos:", colors.black, uiColors.MODAL_BG) drawText(modal.x + 15, line, (t.homeX and t.homeY and t.homeZ) and (t.homeX .. ", " .. t.homeY .. ", " .. t.homeZ) or "Not Set", colors.black, uiColors.MODAL_BG) line = line + 1
        drawText(modal.x + 3, line, "Home Dist:", colors.black, uiColors.MODAL_BG) drawText(modal.x + 15, line, t.distToHome and (t.distToHome .. " blocks") or "N/A", colors.black, uiColors.MODAL_BG) line = line + 1
        drawText(modal.x + 3, line, "Version:", colors.black, uiColors.MODAL_BG) drawText(modal.x + 15, line, tostring(t.version or "v1.0.0"), colors.black, uiColors.MODAL_BG)

        drawText(modal.x + 3, modal.y + 12, " [ APPS ] ", colors.black, colors.lime)
        drawText(modal.x + 18, modal.y + 12, " [ RENAME ] ", colors.black, colors.yellow)
        drawText(modal.x + 33, modal.y + 12, " [ UPDATE ] ", colors.white, colors.purple)
        drawText(modal.x + 3, modal.y + 14, " [ CANCEL ] ", colors.white, colors.red)
        drawText(modal.x + 18, modal.y + 14, " [ SET HOME ] ", colors.black, colors.lightBlue)
        drawText(modal.x + 33, modal.y + 14, " [ REFUEL ]  ", colors.black, colors.lime)
    end

    -- Apps Modal
    if apps.isOpen and state.selectedID then
        ensureAppsPos(w, h)
        local aX, aY = apps.x, apps.y
        term.setBackgroundColor(colors.black)
        for row = aY + 1, aY + apps.height do term.setCursorPos(aX + 1, row) term.write(string.rep(" ", apps.width)) end
        term.setBackgroundColor(colors.lightGray)
        for row = aY, aY + apps.height - 1 do term.setCursorPos(aX, row) term.write(string.rep(" ", apps.width)) end
        drawText(aX, aY, string.rep(" ", apps.width), colors.white, colors.blue)
        drawText(aX + 1, aY, "APPS MENU", colors.white, colors.blue)
        drawText(aX + apps.width - 4, aY, " [X] ", colors.white, colors.red)

        drawText(aX + 3, aY + 2, " [ 1. MANUAL WASD DRIVE ] ", colors.black, colors.lime)
        drawText(aX + 3, aY + 4, " [ 2. REMOTE TELNET / CMD ] ", colors.black, colors.cyan)
        drawText(aX + 3, aY + 6, " [ 3. DEPOSIT INVENTORY ] ", colors.black, colors.orange)
        drawText(aX + 3, aY + 8, " [ 4. RETURN TO HOME ] ", colors.white, colors.red)
        drawText(aX + 3, aY + 10, " [ 5. MINING PROGRAM ] ", colors.black, colors.yellow)
    end

    -- Mining Program Modal (Chunk Strip & Chosen Chunk Options)
    if oreModal.isOpen and state.selectedID then
        ensureOrePos(w, h)
        local oX, oY = oreModal.x, oreModal.y
        term.setBackgroundColor(colors.black)
        for row = oY + 1, oY + oreModal.height do term.setCursorPos(oX + 1, row) term.write(string.rep(" ", oreModal.width)) end
        term.setBackgroundColor(colors.lightGray)
        for row = oY, oY + oreModal.height - 1 do term.setCursorPos(oX, row) term.write(string.rep(" ", oreModal.width)) end
        drawText(oX, oY, string.rep(" ", oreModal.width), colors.white, colors.blue)
        drawText(oX + 1, oY, "MINING PROGRAM", colors.white, colors.blue)
        drawText(oX + oreModal.width - 4, oY, " [X] ", colors.white, colors.red)

        if oreModal.subPage == "menu" then
            drawText(oX + 3, oY + 2, "Select Mining Program Mode:", colors.black, colors.lightGray)

            drawText(oX + 3, oY + 5, " [ CHUNK STRIP ] ", colors.black, colors.lime)
            drawText(oX + 22, oY + 5, "Standard Y=48 to -58", colors.black, colors.lightGray)

            drawText(oX + 3, oY + 8, " [ CHOSEN CHUNK ] ", colors.black, colors.yellow)
            drawText(oX + 22, oY + 8, "Custom Range & Mode", colors.black, colors.lightGray)

            drawText(oX + 3, oY + 11, " [ BIRCH FARM ] ", colors.black, colors.green)
            drawText(oX + 22, oY + 11, "Chunk Tree Farm", colors.black, colors.lightGray)

            -- New Wheat Farm Button
            drawText(oX + 3, oY + 14, " [ WHEAT FARM ] ", colors.black, colors.orange)
            drawText(oX + 22, oY + 14, "9x9 Chunk Auto-Farm", colors.black, colors.lightGray)
        elseif oreModal.subPage == "chosen" then
            drawText(oX + 2, oY + 2, "Configure Custom Chunk Range:", colors.black, colors.lightGray)

            -- Top Y Input
            local topBg = (oreModal.activeField == "topY") and colors.white or colors.gray
            local topFg = (oreModal.activeField == "topY") and colors.black or colors.white
            drawText(oX + 3, oY + 4, "Top Y Level:    ", colors.black, colors.lightGray)
            drawText(oX + 19, oY + 4, " " .. string.format("%-6s", oreModal.topY) .. " ", topFg, topBg)

            -- Bottom Y Input
            local botBg = (oreModal.activeField == "bottomY") and colors.white or colors.gray
            local botFg = (oreModal.activeField == "bottomY") and colors.black or colors.white
            drawText(oX + 3, oY + 6, "Bottom Y Level: ", colors.black, colors.lightGray)
            drawText(oX + 19, oY + 6, " " .. string.format("%-6s", oreModal.bottomY) .. " ", botFg, botBg)

            -- Strategy Selection
            drawText(oX + 3, oY + 8, "Mining Type:", colors.black, colors.lightGray)
            local oreBtnBg = (oreModal.strategy == "ore") and colors.lime or colors.gray
            local fullBtnBg = (oreModal.strategy == "full") and colors.orange or colors.gray
            drawText(oX + 3, oY + 10, " [ STRIP FOR ORE ] ", colors.black, oreBtnBg)
            drawText(oX + 22, oY + 10, " [ FULL CLEAR ALL ] ", colors.black, fullBtnBg)

            -- Confirm / Back
            drawText(oX + 3, oY + 13, " [ START MINING ] ", colors.white, colors.green)
            drawText(oX + 24, oY + 13, " [ BACK ] ", colors.white, colors.red)
        end
    end

    -- Manual Drive Modal
    if drive.isDriving and state.selectedID then
        ensureDrivePos(w, h)
        local dX, dY = drive.x, drive.y
        term.setBackgroundColor(colors.black)
        for row = dY + 1, dY + drive.height do term.setCursorPos(dX + 1, row) term.write(string.rep(" ", drive.width)) end
        term.setBackgroundColor(colors.gray)
        for row = dY, dY + drive.height - 1 do term.setCursorPos(dX, row) term.write(string.rep(" ", drive.width)) end
        drawText(dX, dY, string.rep(" ", drive.width), colors.white, colors.orange)
        drawText(dX + 1, dY, "MANUAL DRIVE: #" .. state.selectedID, colors.black, colors.orange)
        drawText(dX + drive.width - 4, dY, " [X] ", colors.white, colors.red)
        drawText(dX + 2, dY + 2, " [W/S] Forward/Back   [A/D] Turn L/R", colors.white, colors.gray)
        drawText(dX + 2, dY + 4, " [Space/Shift] Move Up/Down", colors.white, colors.gray)
        drawText(dX + 2, dY + 6, " [E] Dig Forward      [Q] Place Forward", colors.white, colors.gray)
    end

    -- Rename Modal
    if rename.isRenaming and state.selectedID then
        ensureRenamePos(w, h)
        local rX, rY = rename.x, rename.y
        term.setBackgroundColor(colors.black)
        for row = rY + 1, rY + rename.height do term.setCursorPos(rX + 1, row) term.write(string.rep(" ", rename.width)) end
        term.setBackgroundColor(colors.gray)
        for row = rY, rY + rename.height - 1 do term.setCursorPos(rX, row) term.write(string.rep(" ", rename.width)) end
        drawText(rX, rY, string.rep(" ", rename.width), colors.white, colors.blue)
        drawText(rX + 1, rY, "RENAME TURTLE #" .. state.selectedID, colors.white, colors.blue)
        drawText(rX + rename.width - 4, rY, " [X] ", colors.lightGray, colors.red)
        term.setBackgroundColor(colors.white) term.setCursorPos(rX + 2, rY + 3) term.write(string.rep(" ", rename.width - 4))
        drawText(rX + 3, rY + 3, (rename.buffer .. "_"):sub(1, rename.width - 5), colors.black, colors.white)
        drawText(rX + 3, rY + rename.height - 2, " [ CONFIRM ] ", colors.black, colors.lime)
        drawText(rX + rename.width - 13, rY + rename.height - 2, " [ CANCEL ] ", colors.white, colors.red)
    end

    -- Telnet Modal
    if telnet.isConnected and state.selectedID then
        ensureTelnetPos(w, h)
        local tX, tY = telnet.x, telnet.y
        term.setBackgroundColor(colors.black)
        for row = tY + 1, tY + telnet.height do term.setCursorPos(tX + 1, row) term.write(string.rep(" ", telnet.width)) end
        term.setBackgroundColor(colors.black)
        for row = tY, tY + telnet.height - 1 do term.setCursorPos(tX, row) term.write(string.rep(" ", telnet.width)) end
        drawText(tX, tY, string.rep(" ", telnet.width), colors.white, colors.cyan)
        drawText(tX + 1, tY, "TELNET: #" .. state.selectedID, colors.black, colors.cyan)
        drawText(tX + telnet.width - 4, tY, " [X] ", colors.white, colors.red)
        local startIdx = math.max(1, #telnet.buffer - (telnet.height - 4) + 1)
        for i = startIdx, #telnet.buffer do
            local line = telnet.buffer[i]:sub(1, telnet.width - 2)
            drawText(tX + 1, tY + 1 + (i - startIdx), line, line:sub(1, 1) == ">" and colors.yellow or colors.lime, colors.black)
        end
        drawText(tX + 1, tY + telnet.height - 2, "> " .. (telnet.input .. "_"):sub(1, telnet.width - 15), colors.white, colors.black)
        drawText(tX + telnet.width - 11, tY + telnet.height - 2, " [ SEND ] ", colors.black, colors.lime)
    end

    -- Client Update Modal
    if update.isUpdating then
        ensureUpdatePos(w, h)
        local uX, uY = update.x, update.y
        term.setBackgroundColor(colors.black)
        for row = uY + 1, uY + update.height do term.setCursorPos(uX + 1, row) term.write(string.rep(" ", update.width)) end
        term.setBackgroundColor(colors.lightGray)
        for row = uY, uY + update.height - 1 do term.setCursorPos(uX, row) term.write(string.rep(" ", update.width)) end
        local titleBg = (update.success == true and colors.lime) or (update.success == false and colors.red) or colors.purple
        drawText(uX, uY, string.rep(" ", update.width), colors.white, titleBg)
        drawText(uX + 1, uY, "WIRELESS CLIENT UPDATE", colors.white, titleBg)
        drawText(uX + update.width - 4, uY, " [X] ", colors.white, colors.red)
        drawText(uX + 2, uY + 2, update.msg:sub(1, update.width - 4), colors.black, colors.lightGray)
        if update.success ~= nil then drawText(uX + math.floor((update.width - 6) / 2), uY + 4, " [ OK ] ", colors.black, colors.lime) end
    end
end

local function handleMouseClick(button, x, y)
    local w, h = term.getSize()

    if update.isUpdating then
        ensureUpdatePos(w, h)
        local uX, uY = update.x, update.y
        if y == uY and x >= uX and x < (uX + update.width) then
            if x >= (uX + update.width - 4) then update.isUpdating = false return end
            update.isDragging = true update.dragOffsetX = x - uX update.dragOffsetY = y - uY
            return
        end
        if update.success ~= nil and y == uY + 4 and x >= (uX + math.floor((update.width - 6) / 2)) and x <= (uX + math.floor((update.width - 6) / 2) + 7) then
            update.isUpdating = false
        end
        return
    end

    if oreModal.isOpen and state.selectedID then
        ensureOrePos(w, h)
        local oX, oY = oreModal.x, oreModal.y
        if y == oY and x >= oX and x < (oX + oreModal.width) then
            if x >= (oX + oreModal.width - 4) then closeOreModal() return end
            oreModal.isDragging = true oreModal.dragOffsetX = x - oX oreModal.dragOffsetY = y - oY
            return
        end

        if oreModal.subPage == "menu" then
            if y == oY + 5 and x >= oX + 3 and x <= oX + 20 then
                sendMiningCommand({ mode = "Chunk Strip" })
                closeOreModal()
            elseif y == oY + 8 and x >= oX + 3 and x <= oX + 21 then
                oreModal.subPage = "chosen"
            elseif y == oY + 11 and x >= oX + 3 and x <= oX + 19 then
                sendMiningCommand({ mode = "Birch Farm" })
                closeOreModal()
            elseif y == oY + 14 and x >= oX + 3 and x <= oX + 19 then
                sendMiningCommand({ mode = "Wheat Farm" })
                closeOreModal()
            end
        elseif oreModal.subPage == "chosen" then
            if y == oY + 4 and x >= oX + 19 and x <= oX + 27 then
                oreModal.activeField = "topY"
            elseif y == oY + 6 and x >= oX + 19 and x <= oX + 27 then
                oreModal.activeField = "bottomY"
            elseif y == oY + 10 then
                if x >= oX + 3 and x <= oX + 20 then
                    oreModal.strategy = "ore"
                elseif x >= oX + 22 and x <= oX + 40 then
                    oreModal.strategy = "full"
                end
            elseif y == oY + 13 then
                if x >= oX + 3 and x <= oX + 20 then
                    local tY = tonumber(oreModal.topY) or 48
                    local bY = tonumber(oreModal.bottomY) or -58
                    sendMiningCommand({
                        mode = "Chosen Chunk",
                        topY = tY,
                        bottomY = bY,
                        strategy = oreModal.strategy
                    })
                    closeOreModal()
                elseif x >= oX + 24 and x <= oX + 33 then
                    oreModal.subPage = "menu"
                end
            end
        end
        return
    end

    if apps.isOpen and state.selectedID then
        ensureAppsPos(w, h)
        local aX, aY = apps.x, apps.y
        if y == aY and x >= aX and x < (aX + apps.width) then
            if x >= (aX + apps.width - 4) then closeApps() return end
            apps.isDragging = true apps.dragOffsetX = x - aX apps.dragOffsetY = y - aY
            return
        end

        if x >= aX and x <= (aX + apps.width) then
            if y == aY + 2 then drive.isDriving = true closeApps() return
            elseif y == aY + 4 then telnet.isConnected = true telnet.buffer = {"Connected to #" .. state.selectedID} closeApps() return
            elseif y == aY + 6 then rednet.send(state.selectedID, { type = "deposit" }, PROTOCOL) closeApps() return
            elseif y == aY + 8 then triggerReturnHome() closeApps() return
            elseif y == aY + 10 then oreModal.isOpen = true closeApps() return end
        end
        return
    end

    if drive.isDriving then
        ensureDrivePos(w, h)
        local dX, dY = drive.x, drive.y
        if y == dY and x >= dX and x < (dX + drive.width) then
            if x >= (dX + drive.width - 4) then drive.isDriving = false return end
            drive.isDragging = true drive.dragOffsetX = x - dX drive.dragOffsetY = y - dY
            return
        end
        return
    end

    if telnet.isConnected then
        ensureTelnetPos(w, h)
        local tX, tY = telnet.x, telnet.y
        if y == tY and x >= tX and x < (tX + telnet.width) then
            if x >= (tX + telnet.width - 4) then closeTelnet() return end
            telnet.isDragging = true telnet.dragOffsetX = x - tX telnet.dragOffsetY = y - tY
            return
        end
        if y == (tY + telnet.height - 2) and x >= (tX + telnet.width - 11) then
            if state.selectedID and #telnet.input > 0 then
                rednet.send(state.selectedID, { type = "manual_cmd", action = telnet.input }, PROTOCOL)
                table.insert(telnet.buffer, "> " .. telnet.input) telnet.input = ""
            end
            return
        end
        return
    end

    if rename.isRenaming then
        ensureRenamePos(w, h)
        local rX, rY = rename.x, rename.y
        if y == rY and x >= rX and x < (rX + rename.width) then
            if x >= (rX + rename.width - 4) then cancelRename() return end
            rename.isDragging = true rename.dragOffsetX = x - rX rename.dragOffsetY = y - rY
            return
        end
        if y == (rY + rename.height - 2) then
            if x >= (rX + 3) and x <= (rX + 15) then
                if state.selectedID and #rename.buffer > 0 then rednet.send(state.selectedID, { type = "rename", newName = rename.buffer }, PROTOCOL) end
                cancelRename() return
            elseif x >= (rX + rename.width - 13) then cancelRename() return end
        end
        return
    end

    if state.selectedID and state.turtles[state.selectedID] then
        ensureModalPos(w, h)
        if x >= modal.x and x < (modal.x + modal.width) and y >= modal.y and y < (modal.y + modal.height) then
            if y == modal.y then
                if x >= (modal.x + modal.width - 4) then state.selectedID = nil closeApps() return end
                modal.isDragging = true modal.dragOffsetX = x - modal.x modal.dragOffsetY = y - modal.y
                return
            end
            if y == modal.y + 12 then
                if x >= (modal.x + 3) and x <= (modal.x + 13) then apps.isOpen = true return
                elseif x >= (modal.x + 18) and x <= (modal.x + 29) then rename.isRenaming = true rename.buffer = state.turtles[state.selectedID].name or "" return
                elseif x >= (modal.x + 33) and x <= (modal.x + 44) then triggerTurtleUpdate() return end
            elseif y == modal.y + 14 then
                if x >= (modal.x + 3) and x <= (modal.x + 14) then 
                    rednet.send(state.selectedID, { type = "stop" }, PROTOCOL)
                    if state.turtles[state.selectedID] then state.turtles[state.selectedID].status = "Idle" end
                    return
                elseif x >= (modal.x + 18) and x <= (modal.x + 31) then triggerSetHome() return
                elseif x >= (modal.x + 33) and x <= (modal.x + 44) then rednet.send(state.selectedID, { type = "refuel" }, PROTOCOL) return end
            end
            return
        else
            state.selectedID = nil closeApps() return
        end
    end

    if state.viewMode == "map" then
        if y == 1 then
            if x >= (w - 18) and x <= (w - 11) then state.viewMode = "table"
            elseif x >= (w - 9) then triggerMassUpdate() end
        elseif y >= 2 then
            for _, p in ipairs(getMapPlottedTurtles(w, h)) do
                if p.x == x and p.y == y then state.selectedID = p.id closeApps() break end
            end
        end
        return
    end

    if y == 1 then
        if x >= (w - 28) and x <= (w - 19) then state.currentSortMode = (state.currentSortMode % #state.sortModes) + 1
        elseif x >= (w - 17) and x <= (w - 11) then state.viewMode = "map"
        elseif x >= (w - 9) then triggerMassUpdate() end
        return
    end

    if y >= 3 and y <= h and state.viewMode == "table" then
        local sorted = getSortedTurtles()
        local rowIndex = (y - 2) + state.scrollOffset
        if sorted[rowIndex] then state.selectedID = sorted[rowIndex].id closeApps() end
    end
end

local function handleKeyInput(event, p1)
    if oreModal.isOpen and oreModal.subPage == "chosen" then
        if event == "char" then
            if p1:match("[0-9%-]") then
                local field = oreModal.activeField
                if #oreModal[field] < 6 then
                    oreModal[field] = oreModal[field] .. p1
                end
            end
        elseif event == "key" then
            if p1 == keys.backspace then
                local field = oreModal.activeField
                oreModal[field] = oreModal[field]:sub(1, -2)
            elseif p1 == keys.tab or p1 == keys.up or p1 == keys.down then
                oreModal.activeField = (oreModal.activeField == "topY") and "bottomY" or "topY"
            elseif p1 == keys.escape then
                closeOreModal()
            end
        end
        return
    end

    if drive.isDriving and state.selectedID then
        if event == "key" then
            if p1 == keys.w then rednet.send(state.selectedID, { type = "manual_cmd", action = "forward" }, PROTOCOL)
            elseif p1 == keys.s then rednet.send(state.selectedID, { type = "manual_cmd", action = "back" }, PROTOCOL)
            elseif p1 == keys.a then rednet.send(state.selectedID, { type = "manual_cmd", action = "turnLeft" }, PROTOCOL)
            elseif p1 == keys.d then rednet.send(state.selectedID, { type = "manual_cmd", action = "turnRight" }, PROTOCOL)
            elseif p1 == keys.space then rednet.send(state.selectedID, { type = "manual_cmd", action = "up" }, PROTOCOL)
            elseif p1 == keys.leftShift or p1 == keys.rightShift then rednet.send(state.selectedID, { type = "manual_cmd", action = "down" }, PROTOCOL)
            elseif p1 == keys.e then rednet.send(state.selectedID, { type = "manual_cmd", action = "dig" }, PROTOCOL)
            elseif p1 == keys.q then rednet.send(state.selectedID, { type = "manual_cmd", action = "place" }, PROTOCOL)
            elseif p1 == keys.escape then drive.isDriving = false end
        end
        return
    end

    if telnet.isConnected then
        if event == "char" and #telnet.input < 30 then telnet.input = telnet.input .. p1
        elseif event == "key" then
            if p1 == keys.backspace then telnet.input = telnet.input:sub(1, -2)
            elseif p1 == keys.enter and state.selectedID and #telnet.input > 0 then
                rednet.send(state.selectedID, { type = "manual_cmd", action = telnet.input }, PROTOCOL)
                table.insert(telnet.buffer, "> " .. telnet.input) telnet.input = ""
            elseif p1 == keys.escape then closeTelnet() end
        end
        return
    end

    if rename.isRenaming then
        if event == "char" and #rename.buffer < 20 then rename.buffer = rename.buffer .. p1
        elseif event == "key" then
            if p1 == keys.backspace then rename.buffer = rename.buffer:sub(1, -2)
            elseif p1 == keys.enter and state.selectedID and #rename.buffer > 0 then
                rednet.send(state.selectedID, { type = "rename", newName = rename.buffer }, PROTOCOL)
                cancelRename()
            elseif p1 == keys.escape then cancelRename() end
        end
        return
    end

    if (apps.isOpen or oreModal.isOpen) and event == "key" and p1 == keys.escape then closeApps() closeOreModal() end
end

local function guiLoop()
    while true do
        drawUI()
        local event, p1, p2, p3 = os.pullEvent()
        if event == "mouse_click" then handleMouseClick(p1, p2, p3)
        elseif event == "char" or event == "key" then handleKeyInput(event, p1)
        elseif event == "mouse_drag" then
            local w, h = term.getSize()
            if update.isDragging then
                update.x = math.max(1, math.min(p2 - update.dragOffsetX, w - update.width + 1))
                update.y = math.max(1, math.min(p3 - update.dragOffsetY, h - update.height + 1))
            elseif oreModal.isDragging then
                oreModal.x = math.max(1, math.min(p2 - oreModal.dragOffsetX, w - oreModal.width + 1))
                oreModal.y = math.max(1, math.min(p3 - oreModal.dragOffsetY, h - oreModal.height + 1))
            elseif apps.isDragging then
                apps.x = math.max(1, math.min(p2 - apps.dragOffsetX, w - apps.width + 1))
                apps.y = math.max(1, math.min(p3 - apps.dragOffsetY, h - apps.height + 1))
            elseif telnet.isDragging then
                telnet.x = math.max(1, math.min(p2 - telnet.dragOffsetX, w - telnet.width + 1))
                telnet.y = math.max(1, math.min(p3 - telnet.dragOffsetY, h - telnet.height + 1))
            elseif rename.isDragging then
                rename.x = math.max(1, math.min(p2 - rename.dragOffsetX, w - rename.width + 1))
                rename.y = math.max(1, math.min(p3 - rename.dragOffsetY, h - rename.height + 1))
            elseif drive.isDragging then
                drive.x = math.max(1, math.min(p2 - drive.dragOffsetX, w - drive.width + 1))
                drive.y = math.max(1, math.min(p3 - drive.dragOffsetY, h - drive.height + 1))
            elseif modal.isDragging then
                modal.x = math.max(1, math.min(p2 - modal.dragOffsetX, w - modal.width + 1))
                modal.y = math.max(1, math.min(p3 - modal.dragOffsetY, h - modal.height + 1))
            end
        elseif event == "mouse_up" then
            update.isDragging = false
            oreModal.isDragging = false
            apps.isDragging = false
            drive.isDragging = false
            telnet.isDragging = false
            rename.isDragging = false
            modal.isDragging = false
        elseif event == "mouse_scroll" and not (telnet.isConnected or rename.isRenaming or update.isUpdating or drive.isDriving or apps.isOpen or oreModal.isOpen) then
            state.scrollOffset = math.max(0, math.min(state.scrollOffset + p1, math.max(0, #getSortedTurtles() - (term.getSize() - 2))))
        end
    end
end

local function broadcastVersionLoop()
    while true do
        local latestVer = getStoredClientVersion()
        if latestVer then
            rednet.broadcast({
                type = "version_sync",
                masterVersion = latestVer,
                version = latestVer
            }, PROTOCOL)
        end
        sleep(5)
    end
end

local function networkLoop()
    while true do
        local senderID, msg = rednet.receive(PROTOCOL)
        if type(msg) == "table" then
            if msg.id then
                local latestVer = getStoredClientVersion()
                
                if latestVer and msg.version ~= latestVer then
                    msg.status = "Outdated Version"
                end
                
                state.turtles[msg.id] = msg
            elseif msg.type == "remote_response" and telnet.isConnected and senderID == state.selectedID then
                if msg.lines then for _, line in ipairs(msg.lines) do table.insert(telnet.buffer, line) end end
            elseif msg.type == "update_response" and update.isUpdating and senderID == state.selectedID then
                update.success = msg.success update.msg = msg.message or "Update completed!"
            end
            os.queueEvent("ui_redraw")
        end
    end
end

parallel.waitForAny(guiLoop, networkLoop, broadcastVersionLoop)