os.loadAPI("sMove.lua")
local networkController = {rednet.lookup("sloppyAdmin")}

local function farm()
  local startingOrientaion = sMove.defineOrientation()
  local turtleOrientation = {"north", "east", "south", "west"}
  local myX, myY,myZ = gps.locate()

  if turtleOrientation[startingOrientaion] == "north" then
    sMove.goTo(myX,myY,myZ-9)
    sMove.goTo(myX+1,myY,myZ-9)
    sMove.goTo(myX+1,myY,myZ)
    sMove.goTo(myX,myY,myZ)
    sMove.setOrientation(turtleOrientation[startingOrientaion])
  elseif turtleOrientation[startingOrientaion] == "east" then
    sMove.goTo(myX+9,myY,myZ)
    sMove.goTo(myX+9,myY,myZ+1)
    sMove.goTo(myX,myY,myZ+1)
    sMove.goTo(myX,myY,myZ)
    sMove.setOrientation(turtleOrientation[startingOrientaion])
  elseif turtleOrientation[startingOrientaion] == "south" then
    sMove.goTo(myX,myY,myZ+9)
    sMove.goTo(myX-1,myY,myZ+9)
    sMove.goTo(myX-1,myY,myZ)
    sMove.goTo(myX,myY,myZ)
    sMove.setOrientation(turtleOrientation[startingOrientaion])
  elseif turtleOrientation[startingOrientaion] == "west" then
    sMove.goTo(myX-9,myY,myZ)
    sMove.goTo(myX-9,myY,myZ-1)
    sMove.goTo(myX,myY,myZ-1)
    sMove.goTo(myX,myY,myZ)
    sMove.setOrientation(turtleOrientation[startingOrientaion])
  end
end

local function deposit()
    for i=1,16 do
        turtle.select(i)
        turtle.dropDown(64)
    end
    turtle.select(1)
end

while true do
    --[[for k,v in pairs(networkController) do
        rednet.send(v,"state","sloppyNetwork")
    end]]-- REDUNDENT
    for k,v in pairs(networkController) do
        local id,message,protocol = rednet.receive(2)
        if id == v and message == "active" and protocol == "sloppyNetwork" then
            term.clear()
            term.setCursorPos(1,1)
            print("Active")
            farm()
            deposit()
        else
            term.clear()
            term.setCursorPos(1,1)
            print("Inactive")
        end
    end
end
