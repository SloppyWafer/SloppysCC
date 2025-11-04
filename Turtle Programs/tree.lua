os.loadAPI("sMove.lua")
term.clear()
term.setCursorPos(1,1)
print("Welcome Sloppy")

local function deposit()
    for i=1,16 do
        turtle.select(i)
        turtle.dropDown(64)
    end
    turtle.select(1)
end

local function chop()
    turtle.dig()
    turtle.forward()
    while turtle.detectUp() do
        turtle.digUp()
        turtle.up()
    end
    deposit()
end

local function replant()
    turtle.turnLeft()
    turtle.forward()
    turtle.select(1)
    turtle.suckDown(1)
    turtle.back()
    turtle.turnRight()
    turtle.forward()
    turtle.forward()
    turtle.down()
    turtle.place()
    turtle.up()
    deposit()
    turtle.back()
    turtle.back()

end

local function farm()
    local startingOrientaion = sMove.defineOrientation()
    local turtleOrientation = {"north", "east", "south", "west"}
    local xHome,yHome,zHome = gps.locate()

    if turtleOrientation[startingOrientaion] == "north" then
        sMove.goTo(xHome,yHome-1,zHome+2)
        chop()
        sMove.goTo(xHome,yHome,zHome)
        sMove.setOrientation(turtleOrientation[startingOrientaion])
        replant()
    elseif turtleOrientation[startingOrientaion] == "east" then
        sMove.goTo(xHome+2,yHome-1,zHome)
        chop()
        sMove.goTo(xHome,yHome,zHome)
        sMove.setOrientation(turtleOrientation[startingOrientaion])
        replant()
    elseif turtleOrientation[startingOrientaion] == "south" then
        sMove.goTo(xHome,yHome-1,zHome-2)
        chop()
        sMove.goTo(xHome,yHome,zHome)
        sMove.setOrientation(turtleOrientation[startingOrientaion])
        replant()
    elseif turtleOrientation[startingOrientaion] == "west" then
        sMove.goTo(xHome-2,yHome-1,zHome)
        chop()
        sMove.goTo(xHome,yHome,zHome)
        sMove.setOrientation(turtleOrientation[startingOrientaion])
        replant()
    end
end
