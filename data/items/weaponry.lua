local jutils = require("src.jutils")
local tiles = require("src.tiles")
local backgrounds = require("src.backgrounds")
local input = require("src.input")
local grid = require("src.grid")
local collision = require("src.collision")

local function getPlayerTile(playerentity)
	local pos = playerentity.position

	return grid.pixelToTileXY(pos.x, pos.y)
end

local function magnitude(x1, y1, x2, y2)
	return math.sqrt( (x2 - x1)^2 + (y2-y1)^2 )
end


local swish_sfx_3 = love.audio.newSource("assets/audio/swish3.ogg", "static")
local swish_sfx_4 = love.audio.newSource("assets/audio/swish4.ogg", "static")

local bullet = baseitem:subclass("Bullet") do
    bullet.texture = love.graphics.newImage("assets/items/bullet.png")
    bullet.stack = 999
end

bullet:new("BULLET", {
    tooltip = ""
})

bullet:new("SILVER_BULLET", {
    tooltip = ""
})

bullet:new("FRAGMENT_BULLET", {
    tooltip = ""
})

bullet:new("HOLY_BULLET", {
    tooltip = ""
})

bullet:new("NANOBULLET", {
    tooltip = ""
})

local function firearm_use(gun, player)
    local unit = (jutils.vec2.new(input.getTransformedMouse())-player.position):unitvec()
    local summonPos = player.position + unit*16

    local acc = math.random(gun.inaccuracy) - (gun.inaccuracy/2)
    local dir = jutils.vec2.fromAngleRadians(math.rad(unit:angle()+acc))

    local bullet_type

    if player.gui.inventory:hasItem(itemlist.BULLET.id, 1) then
        player.gui.inventory:removeItem(itemlist.BULLET.id, 1)
        bullet_type = "bullet"
    end
    if player.gui.inventory:hasItem(itemlist.SILVER_BULLET.id, 1) then
        player.gui.inventory:removeItem(itemlist.SILVER_BULLET.id, 1)
        bullet_type = "silver_bullet"
    end
    if player.gui.inventory:hasItem(itemlist.NANOBULLET.id, 1) then
        player.gui.inventory:removeItem(itemlist.NANOBULLET.id, 1)
        bullet_type = "bullet"
    end
    if player.gui.inventory:hasItem(itemlist.HOLY_BULLET.id, 1) then
        player.gui.inventory:removeItem(itemlist.HOLY_BULLET.id, 1)
        bullet_type = "bullet"
    end
    if player.gui.inventory:hasItem(itemlist.FRAGMENT_BULLET.id, 1) then
        player.gui.inventory:removeItem(itemlist.FRAGMENT_BULLET.id, 1)
        bullet_type = "bullet"
    end

    if bullet_type then
        local bullet = player.world:addEntity(bullet_type, summonPos, dir, gun.power, gun.damage)
        return true, bullet
    end
end

local gun = baseitem:subclass("Gun") do
    gun.damage = 1
    gun.power = 0
    gun.inaccuracy = 12
end

gun:new("FLINTLOCK", {
    displayname = "FLINTLOCK PISTOL",
    speed = 0.6,
    texture = "flintlock.png",
    tooltip = "work in progress bruh",
    stack = 1,
    playeranim = pointanim(false),
    inWorldScale = 2,
    --defaultRotation = math.rad(90),
    playerHoldPosition = jutils.vec2.new(0, 4),
    use = firearm_use,
    damage = 3,
    power = 0,
    inaccuracy = 4,
})

gun:new("LUGER", {
    displayname = "LUGER",
    speed = 1,
    texture = "luger.png",
    stack = 1,
    use = firearm_use,
    damage = 10,
})

gun:new("BOOMSTICK", {
    texture = "boomstick.png",
    speed = 0.75,
    stack = 1,
    playeranim = pointanim(false),
    inWorldScale = 2,
    damage = 8,
    playerHoldPosition = jutils.vec2.new(2, 5),
    defaultRotation = math.rad(45),
    inaccuracy = 25,
    power = 5,
    use = function(self, player)
        local unit = (jutils.vec2.new(input.getTransformedMouse())-player.position):unitvec()
        local summonPos = player.position + unit*16

        local bullet_type = nil

        if player.gui.inventory:hasItem(itemlist.BULLET.id, 1) then
            player.gui.inventory:removeItem(itemlist.BULLET.id, 1)
            bullet_type = "bullet"
        end
        if player.gui.inventory:hasItem(itemlist.SILVER_BULLET.id, 1) then
            player.gui.inventory:removeItem(itemlist.SILVER_BULLET.id, 1)
            bullet_type = "silverbullet"
        end
        if player.gui.inventory:hasItem(itemlist.NANOBULLET.id, 1) then
            player.gui.inventory:removeItem(itemlist.NANOBULLET.id, 1)
            bullet_type = "bullet"
        end
        if player.gui.inventory:hasItem(itemlist.HOLY_BULLET.id, 1) then
            player.gui.inventory:removeItem(itemlist.HOLY_BULLET.id, 1)
            bullet_type = "bullet"
        end
        if player.gui.inventory:hasItem(itemlist.FRAGMENT_BULLET.id, 1) then
            player.gui.inventory:removeItem(itemlist.FRAGMENT_BULLET.id, 1)
            bullet_type = "bullet"
        end

        if bullet_type ~= nil then
            for i = 1, 3 do
                local acc = math.random(self.inaccuracy) - (self.inaccuracy/2)
                local dir = jutils.vec2.fromAngleRadians(math.rad(unit:angle()+acc))

                local bullet = player.world:addEntity(bullet_type, summonPos:copy(), dir:copy(), self.power, self.damage)
            end
            return true
        end

    end
})

baseitem:new("ARROW", {
    texture = "arrow.png",
    displayname = "ARROW",
    stack = 300,
})

baseitem:new("FLAMING_ARROW", {
    texture = "flaming_arrow.png",
    displayname = "FLAMING ARROW",
    stack = 300,
})

--[[
    slingshot item:
]]

local bow = baseitem:subclass("Bow") do
    bow.stack = 1
    bow.inWorldScale = 1
    bow.playeranim = pointanim(true)

    bow.use = function(self, player)

        if player.gui.inventory:hasItem(itemlist.FLAMING_ARROW.id, 1) then
            player.gui.inventory:removeItem(itemlist.FLAMING_ARROW.id, 1)
            local unit = (jutils.vec2.new(input.getTransformedMouse())-player.position):unitvec()
            local arrow = player.world:addEntity("flamingarrow")
            arrow:teleport(player.position)
            arrow.velocity = unit*350
            return true
        end
        if player.gui.inventory:hasItem(itemlist.ARROW.id, 1) then
            player.gui.inventory:removeItem(itemlist.ARROW.id, 1)
            local unit = (jutils.vec2.new(input.getTransformedMouse())-player.position):unitvec()
            local arrow = player.world:addEntity("arrow")
            arrow:teleport(player.position)
            arrow.velocity = unit*350
            return true
        end
    end
end

bow:new("WOODEN_BOW", {
    displayname = "WOODEN BOW",
    speed = 1/2,
    texture = "bow.png",
})

bow:new("COPPER_BOW", {
    displayname = "COPPER BOW",
    speed = 1/3,
    texture = "bow.png",
})

consumable:new("BOMB", {
    texture = "bomb.png",
    stack = 999,
    speed = 1/2,
    consume = function(self, player)
        local mx, my = input.getTransformedMouse()

        local tx, ty = grid.pixelToTileXY(mx, my)
        local px, py = getPlayerTile(player)

        local world = player.world

        local bombentity = world:addEntity("bombentity", 5, player)
        bombentity:teleport(player.position)
        local mousepos = jutils.vec2.new(mx, my)
        local unitvec = (mousepos - player.position):unitvec()
        bombentity.velocity = unitvec*400

        swish_sfx_3:stop()
        swish_sfx_3:play()
        return true
    end,
})

consumable:new("STICKY_BOMB", {
    texture = "stickybomb.png",
    stack = 999,
    speed = 1/2,
    consume = function(self, player)
        local mx, my = input.getTransformedMouse()

        local tx, ty = grid.pixelToTileXY(mx, my)
        local px, py = getPlayerTile(player)


        local world = player.world

        local bombentity = world:addEntity("stickybomb", 5, player)
        bombentity:teleport(player.position)
        local mousepos = jutils.vec2.new(mx, my)
        local unitvec = (mousepos - player.position):unitvec()
        bombentity.velocity = unitvec*400

        swish_sfx_3:stop()
        swish_sfx_3:play()
        return true
    end,
})

consumable:new("DYNAMITE", {
    texture = "dynamite.png",
    stack = 99,
    speed = 1,
    consume = function(self, player)
        local mx, my = input.getTransformedMouse()

        local tx, ty = grid.pixelToTileXY(mx, my)
        local px, py = getPlayerTile(player)


        local world = player.world

        local bombentity = world:addEntity("dynamite", 5, player)
        bombentity:teleport(player.position)
        local mousepos = jutils.vec2.new(mx, my)
        local unitvec = (mousepos - player.position):unitvec()
        bombentity.velocity = unitvec*400

        swish_sfx_3:stop()
        swish_sfx_3:play()
        return true
    end
})

local SWORD_TOOLTIP =
[[
{speed} Speed
{knockback} Knockback
{range} Range
{damage} Atk Damage
]]

local function swordUse(self, player)
    -- figure out hitbox overlaps
    swish_sfx_4:stop()
    swish_sfx_4:play()
    return true

end

local function swordUseStep(self, player, dt)
    local percent = 1-(player.animation.timer/self.speed)
    if percent > 0.5 then percent = 1-percent end
    percent = percent * 2
    --print(percent)

    local world = player.world

    for _, entity in pairs(world.entities) do
        if entity ~= player and entity.hostile then
            local pos = entity.position
            local box = entity.boundingbox

            local px = player.position.x

            if player.direction == -1 then
                px = px - (self.range*percent)
            end
            if collision.aabb(px, player.position.y-1, self.range*percent, 2, pos.x, pos.y, box.x, box.y) then
                local finaldamage = self.damage
                local variation = (math.random()-0.5)*5
                finaldamage = finaldamage + variation
                local crit = math.random()
                if crit > 0.95 then
                    finaldamage = finaldamage*2
                end

                if entity.invulnerability <= 0 then
                    entity:damage(finaldamage)

                    entity.velocity.x = entity.velocity.x + (player.direction*self.knockback)
                    --entity.velocity.y = -20
                end
            end
        end
    end
    if player.animation.running == false then return true end

end

local function swordUseEnd(self, player)

end

local sword = baseitem:subclass("Sword") do
    sword.texture = love.graphics.newImage("assets/items/sword.png")
    sword.tooltip = SWORD_TOOLTIP
    sword.stack = 1
    sword.inWorldScale = 2
    sword.playeranim = jabanim(false, 20)
    sword.playerHoldPosition = jutils.vec2.new(0, 8)
    sword.defaultRotation = math.rad(45)
    sword.use = swordUse
    sword.usestep = swordUseStep
    sword.useend = swordUseEnd
    sword.holdbegin = function(self, player)

    end
    sword.holdend = function(self, player)

    end
end

local longsword = sword:subclass("Longsword") do
    longsword.playeranim = swinganim()
    longsword.use = function() end
    longsword.usestep = function() end
    longsword.useend = function() end
    
end

sword:new("RUSTY_SWORD", {
    displayname = "RUSTY SWORD",
    speed = 1/4,
    color = {0.7, 0.4, 0.3},
    repeating = false,
    knockback = 30,
    damage = 5,
    range = 20,
})

sword:new("IRON_SWORD", {
    displayname = "IRON SWORD",
    speed = 1/3,
    color = {0.9, 0.8, 0.8},
    repeating = false,
    knockback = 50,
    damage = 8,
    range = 20,
})

sword:new("COPPER_SWORD", {
    displayname = "COPPER SWORD",
    speed = 1/7,
    color = {1, 0.45, 0.0},
    repeating = false,
    knockback = 40,
    damage = 6,
    range = 16,
})

sword:new("LEAD_SWORD", {

})

sword:new("SILVER_SWORD", {

})

longsword:new("PALLADIUM_SWORD", {

})

longsword:new("COBALT_SWORD", {

})

baseitem:new("PUNCHY", {
    displayname = "BLUESTEEL BRASS",
    speed = 1/2,
    texture = "punchy.png",
    stack = 1,
    rarity = 3
})