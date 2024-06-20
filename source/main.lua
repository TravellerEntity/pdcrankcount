import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"
import "CoreLibs/crank"
import "CoreLibs/ui"

local gfx <const> = playdate.graphics
local snd <const> = playdate.sound
local count = 0
if playdate.file.exists("count.json") then
    print(playdate.datastore.read("count")[1])
    count = playdate.datastore.read("count")[1]
end

local counterSprite = nil
local buttonSprite = nil
local armMaskSprite = nil

local numbers = gfx.imagetable.new("assets/images/numbers/num")
assert(numbers)

local clickSound = snd.sampleplayer.new("assets/click")
local unclickSound = snd.sampleplayer.new("assets/unclick")
local dialClickSound = snd.sampleplayer.new("assets/dial_click")
local dialClickSoundWW = snd.sampleplayer.new("assets/dial_click_wrongway")

local buttonAnimator = gfx.animator.new(1, 200, 200)

local counterSpritesList = {}

local hideCrankAlert = false

local function updateCounter()
    local countStr = tostring(count)
    while #countStr < 4 do
        countStr = "0" .. countStr
    end
    for i=1,4 do
        counterSpritesList[i]:setImage(numbers:getImage(tonumber(countStr:sub(i,i))+1))
    end
end

local function setup()
    counterSprite = gfx.sprite.new(gfx.image.new("assets/images/counter"))
    counterSprite:moveTo(200, 120)
    counterSprite:setZIndex(1)
    counterSprite:add()

    buttonSprite = gfx.sprite.new(gfx.image.new("assets/images/button"))
    buttonSprite:moveTo(200, 120)
    buttonSprite:setZIndex(2)
    buttonSprite:add()

    armMaskSprite = gfx.sprite.new(gfx.image.new("assets/images/arm_mask"))
    armMaskSprite:moveTo(200, 120)
    armMaskSprite:setZIndex(3)
    armMaskSprite:add()

    local countStr = tostring(count)
    while #countStr < 4 do
        countStr = "0" .. countStr
    end

    for i=1,4 do
        local temp = gfx.sprite.new(numbers:getImage(tonumber(countStr:sub(i,i))+1))
        temp:setCenter(0,0)
        temp:moveTo(187 + (i-1)*17, 100)
        temp:setZIndex(-1)
        temp:add()
        table.insert(counterSpritesList, temp)
    end

    gfx.sprite.setBackgroundDrawingCallback(
        function(x,y,width,height)
            gfx.setColor(gfx.kColorBlack)
            gfx.fillRect(x,y,width,height)
        end
    )
end

--Changed slightly by me to add the ability to offset the segment positions
--Otherwise taken directly from the SDK
local tick_lastCrankReading = nil
local function getCrankTicks(ticksPerRotation, offset)
	local totalSegments = ticksPerRotation
	local degreesPerSegment = 360 / ticksPerRotation
	
	local thisCrankReading = playdate.getCrankPosition() + offset
    if thisCrankReading > 360 then
        thisCrankReading -= 360
    end
	if tick_lastCrankReading == nil then
		tick_lastCrankReading = thisCrankReading
	end
	
	local difference = thisCrankReading - tick_lastCrankReading
	if difference > 180 or difference < -180 then
		if tick_lastCrankReading >= 180 then
			tick_lastCrankReading -= 360
		else
			tick_lastCrankReading += 360
		end
	end

	local thisSegment = math.ceil(thisCrankReading / degreesPerSegment)
	local lastSegment = math.ceil(tick_lastCrankReading / degreesPerSegment)
	local segmentBoundariesCrossed = thisSegment - lastSegment
	tick_lastCrankReading = thisCrankReading
	return segmentBoundariesCrossed	
end

function playdate.gameWillTerminate()
    local cTbl = {count}
    playdate.datastore.write(cTbl, "count")
end

playdate.getSystemMenu():addMenuItem("Reset", function()
    count = 0
    updateCounter()
end)

playdate.getSystemMenu():addCheckmarkMenuItem("Stay awake", function(val)
    playdate.setAutoLockDisabled(val)
    print(val)
end)

setup()

function playdate.update()
    if playdate.isCrankDocked() == false then
        hideCrankAlert = true
    end
    if playdate.buttonJustPressed("a") then
        buttonAnimator = gfx.animator.new(40, 200, 180)
        clickSound:play(1)
        count = count + 1
        if count > 9999 then
            count = 0
        end
        updateCounter()
    end
    if playdate.buttonJustReleased("a") then
        buttonAnimator = gfx.animator.new(40, 180, 200)
        unclickSound:play(1)
    end

    buttonSprite:moveTo(buttonAnimator:currentValue(), 120)

    local ticks = getCrankTicks(3, 180)
    if ticks == 1 then
        dialClickSound:play(1)
        count = (count - (count % 1111))
        count = count + 1111
        if count > 9999 then
            count = 0
        end
        updateCounter()
    elseif ticks == -1 then
        dialClickSoundWW:play(1)
    end

    gfx.sprite.update()
    if playdate.isCrankDocked() and hideCrankAlert == false then
        playdate.ui.crankIndicator:draw()
    end
    playdate.timer.updateTimers()
end