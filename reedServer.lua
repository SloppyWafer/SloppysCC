rednet.host("sloppyAdmin", "sloppyAdmin")

local reedTurtles = {rednet.lookup("sloppyReedTurtles")}
local monitor = peripheral.find("monitor")
monitor.setTextScale(0.5)
local w,h = monitor.getSize()
local turtleState = "active"
local buttonState = false

function mcText(myStr,y)
	local w,h = monitor.getSize()
	myStrLen = myStr.len(myStr)
  --print(myStrLen)
	monitor.setCursorPos(math.ceil(w/2)-(math.ceil(myStrLen/2)),y)
	monitor.write(myStr)
end

local function button()
    if buttonState == true then
      monitor.setBackgroundColour(colors.green)
      monitor.clear()
      monitor.setCursorPos(1,1)
      mcText("Reed Turtles",1)
      mcText("Online",h-1)
      buttonState = false
    elseif buttonState == false then
      monitor.setBackgroundColour(colors.red)
      monitor.clear()
      monitor.setCursorPos(1,1)
      mcText("Reed Turtles",1)
      mcText("Offline",h-1)
      buttonState = true
    end
end

local function touchScreen()
  local event, side, x, y = os.pullEvent("monitor_touch")
  if event == "monitor_touch" and x == x and y == y then
    button()
    if buttonState == true then
      turtleState = "inactive"
    elseif buttonState == false then
      turtleState = "active"
    end
  end
end

local function serverListen()
  sleep(1)
  if buttonState == false then
    for k,v in pairs(reedTurtles) do
      rednet.send(v,"active","sloppyNetwork")
    end
  elseif buttonState == true then
    for k,v in pairs(reedTurtles) do
      rednet.send(v,"inactive","sloppyNetwork")
    end
  end
end

while true do
  parallel.waitForAny(touchScreen, serverListen)
end
