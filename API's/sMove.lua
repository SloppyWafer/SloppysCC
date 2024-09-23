function defineOrientation()
  local x,y,z = gps.locate()
  turtle.back()
  local currentX,currentY,currentZ = gps.locate()
  if currentX < x then
    side = 2
    turtle.forward()
    return side
  elseif currentX > x then
    side = 4
    turtle.forward()
    return side
  elseif currentZ < z then
    side = 3
    turtle.forward()
    return side
  elseif currentZ > z then
    side = 1
    turtle.forward()
    return side
  end
end

function setOrientation(side)
  local orientation = {["north"] = 1, ["east"] = 2, ["south"] = 3, ["west"] = 4 }
  --print("Facing: "..facing)
  --print("To Go To: "..orientation[side])
  if facing < orientation[side] then
    for i=facing+1,orientation[side] do
      --print("Turn Right")
      turtle.turnRight()
    end
    facing = orientation[side]
  elseif facing > orientation[side] then
    for i=orientation[side]+1,facing do
      --print("Turn Left")
      turtle.turnLeft()
    end
    facing = orientation[side]
  elseif facing == orientation[side] then
    return
  end
end

function goTo(x,y,z)
  local currentX,currentY,currentZ = gps.locate()
  if currentX > x then
    setOrientation("west")
    while currentX > x do
      turtle.dig()
      turtle.forward()
      currentX,currentY,currentZ = gps.locate()
    end
  elseif currentX < x then
    setOrientation("east")
    while currentX < x do
      turtle.dig()
      turtle.forward()
      currentX,currentY,currentZ = gps.locate()
    end
  end
  if currentZ > z then
    setOrientation("north")
    while currentZ > z do
      turtle.dig()
      turtle.forward()
      currentX,currentY,currentZ = gps.locate()
    end
  elseif currentZ < z then
    setOrientation("south")
    while currentZ < z do
      turtle.dig()
      turtle.forward()
      currentX,currentY,currentZ = gps.locate()
    end
  end
  if currentY > y then
    while currentY > y do
      turtle.digDown()
      turtle.down()
      currentX,currentY,currentZ = gps.locate()
    end
  elseif currentY < y then
    while currentY > y do
      turtle.digUp()
      turtle.up()
      currentX,currentY,currentZ = gps.locate()
    end
  end
end



  facing = defineOrientation()
