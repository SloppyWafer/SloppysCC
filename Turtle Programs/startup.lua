term.clear()
term.setCursorPos(1,1)
textutils.slowPrint("Welcome Sloppy")

for a,b in pairs(rs.getSides()) do
  if peripheral.getType(b) == 'modem' then
   rednet.open(b)
   local networkList = {rednet.host("sloppyReedTurtles",os.getComputerLabel())}
   break
  end
end

shell.run("reedFarm.lua")
