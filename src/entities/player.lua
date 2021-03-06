local jutils = require("src.jutils")
local config = require("config")
local tiles = require("src.tiles")
local grid = require("src.grid")
local input = require("src.input")
local items = require("src.items")
local rendering = require("src.rendering")
local playergui = require("src.playergui")
local particlesystem = require("src.particlesystem")

local humanoid = require("src.entities.humanoid")
local physicalentity = require("src.entities.physicalentity")

local player = humanoid:subclass("Player")

function player:init()
	humanoid.init(self)

	self.texture = love.graphics.newImage("assets/entities/player.png")
	self.boundingbox = jutils.vec2.new(6, 12)
	self.textureorigin = jutils.vec2.new(8, 12)
	self.fallthrough = false
	self.mass = 0.8
	self.spawn_position = nil

	self.inventoryOpen = false
	self.openContainer = nil
	self.guiscale = 2
	self.gui = playergui:new(self)
	self.showMouseTileDistance = -1
	self.hotbarslot = 1
	self.currentSelectedSlot = 0
	self.fast = false
	self.save = true
	self.freemove = false
	self.itemHolding = nil
	self.lastItemHolding = nil
	self.equipDebounce = false
	self.god = false
	self.itemCooldown = 0
	self.itemIsRunning = false
	self.spawntimer = 3
	self.mouse = {
		down = false, bounce = false,
		position = jutils.vec2.new(0, 0)
	}
	self.itemdata = {}
	self.lclicked = false
	self.rclicked = false
	self.lusecooldown = 0
	self.rusecooldown = 0
	self.escapeDebounce = false
	self.animation = {
		timer = 0,
		percentage = 0,
		running = false,
		item = nil,
		walking = false,
		walkstep = 1,
		falling = false,
	}

	self.show_ui = true
	self.waiting_for_chunks = true

	self:scroll(0)
end

function player:serialize()

	local data = {}
	data.type = "player"
	data.x = self.position.x
	data.y = self.position.y
	-- tile coordinates, not pixel coordinates
	if self.spawn_position then
		data.spawn_x = self.spawn_position.x
		data.spawn_y = self.spawn_position.y
	end
	data.health = self.health
	data.defense = self.defense
	data.items = self.gui.inventory.items
	data.equipment = self.gui.equipment.items

	return data
end

function player:deserialize(data)
	if data.spawn_x and data.spawn_y then
		self.spawn_position = jutils.vec2.new(data.spawn_x, data.spawn_y)
	end
	self.nextposition = jutils.vec2.new(data.x, data.y)

	self.health = data.health
	self.defense = data.defense or 0
	self.gui.inventory.items = data.items

	if data.equipment then
		self.gui.equipment.items = data.equipment
	end
end

function player:getHelmet()
	return self.gui.equipment.items[1][1]
end

function player:getChestplate()
	return self.gui.equipment.items[3][1]
end

function player:getLeggings()
	return self.gui.equipment.items[5][1]
end

function player:getAccessories()
	return {
		self.gui.equipment.items[2][1],
		self.gui.equipment.items[4][1],
		self.gui.equipment.items[6][1],
	}
end

function player:equipment_callback(callback, ...)
	for slot, item in pairs(self.gui.equipment.items) do
		local id = item[1]

		if id ~= 0 then
			local data = items:getByID(id)

			if data[callback] then
				data[callback](data, self, ...)
			end
		end
	end
end

function player:collisionCallback(tileid, tilepos, separation, normal)
	humanoid.collisionCallback(self, tileid, tilepos, separation, normal)
	self:equipment_callback("onCollide", tileid, tilepos, separation, normal)
end

local hit_sfx_3 = love.audio.newSource("assets/audio/hit3.ogg", "static")

function player:damage(amount)

	if self.god then return end

	local final_amount = physicalentity.damage(self, amount)

	self:equipment_callback("onDamage", final_amount)

	if final_amount then
		self.knockbackTimer = 0.25

		hit_sfx_3:stop()
		hit_sfx_3:setPitch(self.hurt_yell_pitch)
		hit_sfx_3:play()

		particlesystem.newBloodSplatter(self.position, 1.1)
		local e = self.world:addEntity("floatingtext", math.floor(final_amount), {1, 0.5, 0})
		e:teleport(self.position)
	end
end

function player:dies()
	-- TODO: do something not gay
	self.health = self.maxhealth
	if self.spawn_position then
		print(self.spawn_position)
		self.nextposition = self.spawn_position:copy()
	else
		self.nextposition = jutils.vec2.new(0, self.world.spawnPointY)
	end
	self.dead = false
end

function player:onMousePressed(x, y, button, istouch, presses)
	local result = self.gui:clicked(button, istouch, presses)
	if result == false then
		if button == 1 then self.mouse.down = true end
	end

	local mousex, mousey = grid.pixelToTileXY(input.getTransformedMouse())
	local tile = self.world:getTile(mousex, mousey)
	local tiledata = tiles:getByID(tile)

	if tiledata.playerInteract then
		tiledata.playerInteract(self, mousex, mousey, button)
	end
end

function player:onMouseReleased(x, y, button, istouch, presses)
	if button == 1 then self.mouse.down = false end
end

local hotbarKeys = {
	["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9, ["0"] = 10,
}

function player:onKeyPressed(key)
	if key == "escape" then
		self.gui.open = not self.gui.open
	end

	self:equipment_callback("keyPress", key)

	-- item dropping
	-- TODO: make it's own method
	if key == "q" then
		local stack = self.itemHoldingStack
		if stack then
			local itemstack = self.world:addEntity("itemstack", stack[1], stack[2])

			itemstack:teleport(self.position)
			itemstack.velocity.y = -120
			itemstack.velocity.x = self.direction*200
			itemstack.playermagnet = -1

			stack[1] = 0
			stack[2] = 0
		end
	end


	if key == "p" then self.nextposition = self.mouse.position end

	if hotbarKeys[key] then
		self.hotbarslot = hotbarKeys[key]

		self.gui.hotbarSelection = self.hotbarslot
	end
end

function player:canUseItem()
	if self.itemHolding == nil then return false end
	if self.itemHolding.use == nil then return false end
	if self.itemCooldown > 0 then
		return false
	end
	if self.itemIsRunning == true then return false end
	if self.itemHolding.repeating == true or self.mouse.bounce == false then
		return true
	end
	return false
end


function player:onWheelMoved(x, y)
	self:scroll(y)
end

function player:getMousePosition()
	return self.mouse.position
end

function player:scroll(change)
	if self.gui:scroll(change) == false then
		self.hotbarslot = self.hotbarslot - change

		if self.hotbarslot < 1 then self.hotbarslot = 10 end
		if self.hotbarslot > 10 then self.hotbarslot = 1 end

		self.gui.hotbarSelection = self.hotbarslot
	end
end

function player:inventoryUpdate(dt)
	local item = self.gui:getEquippedItem()
	if item and item[1] > 0 and item[2] > 0 then
		self.itemHolding = items:getByID(item[1])
		self.itemHoldingStack = item
	else
		self.itemHolding = nil
		self.itemHoldingStack = nil
	end
	if self.itemHoldingStack ~= self.lastItemHolding then
		if self.lastItemHolding then
			self.lastItemHolding:holdend(self)
		end
		if self.itemHolding then
			self.itemHolding:holdbegin(self)
		end
		self.lastItemHolding = self.itemHolding
	end

	if self.itemHolding then
		self.itemHolding:holdingStep(self, dt)
	end
end

function player:animation_update(dt)
	humanoid.animation_update(self, dt)
	self.animation.timer = self.animation.timer - dt
	if self.animation.timer <= 0 then
		self.animation.running = false
	end
end

function player:update(dt)

	self.spawntimer = self.spawntimer - dt

	if self.god then

	end
	
	if self.spawntimer > 0 then
		self.frozen = true
		self.waiting_for_chunks = true
	else
		if self.waiting_for_chunks == true then
			self.waiting_for_chunks = false
			self.frozen = false
		end
	end
	humanoid.update(self, dt)
	
	-- item usage
	
	if self.itemIsRunning then
		if self.itemHolding.usestep then
			local res = self.itemHolding:usestep(self, dt)

			if res == true then
				self.itemHolding:useend(self)
				self.itemIsRunning = false
			end
		else
			self.itemIsRunning = false
		end
	end

	self.itemCooldown = self.itemCooldown - dt

	if self.itemIsRunning == false and self.itemCooldown <= 0 then
		self:inventoryUpdate(dt)
	end

	if self.mouse.down then
		
		if self:canUseItem() then
			
			local item = self.itemHolding
			self.itemCooldown = item.speed
			local success = item:use(self)

			if success then
				self.animation.timer = item.speed
				self.animation.running = true
				self.animation.item = self.itemHolding
				self.itemIsRunning = true
			end
		end
		self.mouse.bounce = true
	else
		self.mouse.bounce = false
	end

	self.mouse.position = jutils.vec2.new(input.getTransformedMouse())
	
	-- rope and platform controls
	if self.spawntimer < 0 then

		self.grabrope = love.keyboard.isDown(config.keybinds.PLAYER_MOVE_UP)
		self.fallthrough = love.keyboard.isDown(config.keybinds.PLAYER_MOVE_DOWN)
		self.moveUp = love.keyboard.isDown(config.keybinds.PLAYER_MOVE_UP)
		self.moveDown = love.keyboard.isDown(config.keybinds.PLAYER_MOVE_DOWN)
		self.moveLeft = love.keyboard.isDown(config.keybinds.PLAYER_MOVE_LEFT)
		self.moveRight = love.keyboard.isDown(config.keybinds.PLAYER_MOVE_RIGHT)
		self.jumping = love.keyboard.isDown(config.keybinds.PLAYER_JUMP)
	end

	self:equipment_callback("tick", dt)

	self.gui:update(dt)
end

local function magnitude(x1, y1, x2, y2)
	return math.sqrt( (x2 - x1)^2 + (y2-y1)^2 )
end

local oscillator = 0


--! this is where armour sets are coded in
-- this should probably be moved 
local armor_textures = {
	base  = love.graphics.newImage("assets/armor/basearmor.png"),
	witch = love.graphics.newImage("assets/armor/witch.png"),
}

local tex_w, tex_h = armor_textures.base:getDimensions()

local helmet_quads = {
	[1] = love.graphics.newQuad(0, 0, 16, 8, tex_w, tex_h),
	[2] = love.graphics.newQuad(16, 0, 16, 8, tex_w, tex_h),
	[3] = love.graphics.newQuad(32, 0, 16, 8, tex_w, tex_h),
	[4] = love.graphics.newQuad(48, 0, 16, 8, tex_w, tex_h),
}

local chestplate_quads = {
	[1] = love.graphics.newQuad(0, 8, 16, 12, tex_w, tex_h),
	[2] = love.graphics.newQuad(16, 8, 16, 12, tex_w, tex_h),
	[3] = love.graphics.newQuad(32, 8, 16, 12, tex_w, tex_h),
	[4] = love.graphics.newQuad(48, 8, 16, 12, tex_w, tex_h),
}

local legging_quads = {
	[1] = love.graphics.newQuad(0, 20, 16, 8, tex_w, tex_h),
	[2] = love.graphics.newQuad(16, 20, 16, 8, tex_w, tex_h),
	[3] = love.graphics.newQuad(32, 20, 16, 8, tex_w, tex_h),
	[4] = love.graphics.newQuad(48, 20, 16, 8, tex_w, tex_h),
}


function player:draw()
	
	oscillator = oscillator + (1/20)

	local mousex, mousey = grid.pixelToTileXY(input.getTransformedMouse())

	local tile = self.world:getTile(mousex, mousey)

	-- draw the yellow rectangle around an interactive tile
	if tile > 0 then
		local tiledata = tiles:getByID(tile)

		if tiledata.playerInteract then
			love.graphics.setColor(1, 1, 0, (math.sin(oscillator)+1)/2)

			-- TODO: make glow cover the whole object, instead of one tile
			love.graphics.setLineWidth(1)
			love.graphics.rectangle("line", mousex*config.TILE_SIZE, mousey*config.TILE_SIZE, config.TILE_SIZE, config.TILE_SIZE)
		end
	end
	
	local actionframe = self:getAnimationFrame()

	-- draw the player's texture and animation
	love.graphics.setColor(self.light)
	love.graphics.draw(
		self.texture,
		self.animationframes[actionframe],
		self.position.x, self.position.y, self.rotation, self.scale.x* (-self.direction), self.scale.y,
		self.textureorigin.x, self.textureorigin.y
	)

	-- draw player's equipment
	local helmet      = self.gui.equipment.items[1][1]
	local chestplate  = self.gui.equipment.items[3][1]
	local leggings    = self.gui.equipment.items[5][1]
	local accessory_1 = self.gui.equipment.items[2][1]
	local accessory_2 = self.gui.equipment.items[4][1]
	local accessory_3 = self.gui.equipment.items[6][1]

	-- TODO: make this reflect the lighting of the equipment

	-- draw helmet
	local scale = 1
	if helmet ~= 0 then

		local helmet_data = items:getByID(helmet)

		local color = jutils.color.multiply(helmet_data.color, self.light)

		local offx, offy = 8, 16
		love.graphics.setColor(color)
		love.graphics.draw(armor_textures[helmet_data.set], helmet_quads[actionframe],
			self.position.x, self.position.y, 0, -self.direction, 1, offx, offy
		)
	end

	if leggings ~= 0 then

		local leggings_data = items:getByID(leggings)

		local color = jutils.color.multiply(leggings_data.color, self.light)

		local offx, offy = 8, -4
		love.graphics.setColor(color)
		love.graphics.draw(armor_textures[leggings_data.set], legging_quads[actionframe],
			self.position.x, self.position.y, 0, -self.direction, 1, offx, offy
		)
	end

	if chestplate ~= 0 then

		local chestplate_data = items:getByID(chestplate)

		local color = jutils.color.multiply(chestplate_data.color, self.light)

		local offx, offy = 8, 8
		love.graphics.setColor(color)
		love.graphics.draw(armor_textures[chestplate_data.set], chestplate_quads[actionframe],
			self.position.x, self.position.y, 0, -self.direction, 1, offx, offy
		)
	end
	-- TODO: draw armor and accessories on top of the player

	-- draw the currently using item
	--! this needs to be fixed up, the animations are wonky.
	if self.animation.running then
		local data = self.animation.item
		local item = data.id
		if item>0 then
			local percent = 1-(self.animation.timer/data.speed)

			local style = data.playeranim.style

			if style == "point" then
				local followmouse = data.playeranim.follow
				local rotation = 0

				local dir = self.direction
				if followmouse then

					rotation = self.position:angleBetween(jutils.vec2.new(input.getTransformedMouse()))


					if rotation > 90 then
						dir = -dir
					end

					rotation = math.rad(rotation)
				end

				rendering.drawItem(item, self.position.x, self.position.y,
				data.inWorldScale*(dir), data.inWorldScale, (data.defaultRotation + rotation)*(dir), data.playerHoldPosition.x, data.playerHoldPosition.y)

			end
			
			if style == "jab" then
				local followmouse = data.playeranim.follow

				local full = data.playeranim.length

				if percent > 0.5 then percent = 1-percent end

				local current = percent * full

				local rotation = 0
				if followmouse then
					rotation = math.rad(self.position:angleBetween(jutils.vec2.new(input.getTransformedMouse())))
					
				end
				rendering.drawItem(item, self.position.x+(current*(self.direction)), self.position.y, data.inWorldScale*(self.direction), data.inWorldScale, (rotation+data.defaultRotation)*self.direction, data.playerHoldPosition.x, data.playerHoldPosition.y)
			end

			if style == "swing" then
				local startang = data.playeranim.start
				local dist = data.playeranim.distance
				local currentDist = (percent*dist)
				local angleFixed = (startang + currentDist) * self.direction
				local adjusted = math.rad( ((-self.direction)*data.defaultRotation)+angleFixed)
				
				-- radius, no clue why I have to flip this as well
				local r = 8 * self.direction
				-- shift item by dx and dy for swivel effect
				local dx, dy = math.cos(math.rad(angleFixed))*r, math.sin(math.rad(angleFixed))*r

				rendering.drawItem(item, self.position.x+dx, self.position.y+dy, data.inWorldScale*self.direction, data.inWorldScale, adjusted, data.playerHoldPosition.x, data.playerHoldPosition.y)
			end
		end
	end
	
	-- show mouse pointer.
	local mouse = self:getMousePosition()
	local tmx, tmy = grid.pixelToTileXY(mouse.x, mouse.y)
	local px, py = grid.pixelToTileXY(self.position.x, self.position.y)
	if magnitude(tmx, tmy, px, py) <= self.showMouseTileDistance then
		love.graphics.setColor(1, 1, 1, 0.5)
		love.graphics.setLineWidth(1)
		love.graphics.rectangle("line", tmx*config.TILE_SIZE, tmy*config.TILE_SIZE, config.TILE_SIZE, config.TILE_SIZE)
	end

	humanoid.draw(self)

	--self.gui:draw()
end

return player
