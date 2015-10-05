Container = (function()
	
	-- Imports
	local pingDelay = Core.pingDelay
	local clearTimeout = Core.clearTimeout
	local clearWhen = Core.clearWhen
	local setTimeout = Core.setTimeout
	local setInterval = Core.setInterval
	local when = Core.when
	local formatList = Core.formatList
	local log = Console.log
	local info = Console.info
	local prompt = Console.prompt

	local function getLastContainer()
		local last = 0
		for i = 0, 16 do
			if xeno.getContainerOpen(i) then
				last = i
			end
		end
		return last
	end

	local function getContainerByName(name)
		for i = 0, 16 do
			if xeno.getContainerName(i) == name and xeno.getContainerOpen(i) then
				return i
			end
		end
		return false
	end

	local function compareContainers(a, b)
		-- Different item count, return false
		local itemcount = xeno.getContainerItemCount(a)
		local compcount = xeno.getContainerItemCount(b)
		if itemcount ~= compcount then
			return false
		end
		-- Different name, return false
		if xeno.getContainerName(a) ~= xeno.getContainerName(b) then
			return false
		end
		-- Different slot data, return false
		for spot = 0, itemcount do
			local item = xeno.getContainerSpotData(a, spot)
			local compitem = xeno.getContainerSpotData(b, spot)
			if item.id ~= compitem.id or item.count ~= compitem.count then
				return false
			end
		end
		-- Containers are similar (shallow comparison)
		return true
	end

	local function fixContainerDepth(container, spot, depth, callback)
		local item = xeno.getContainerSpotData(container, spot)
		-- Cascade backpack, last slot of backpack
		if xeno.isItemContainer(item.id) then 
			xeno.containerUseItem(container, spot, true)
		end
		-- Wait for the container to open
		setTimeout(function()
			callback()
		end, pingDelay(DELAY.CONTAINER_USE_ITEM))
	end

	local function resetContainerDepths(source, destination, sDepth, dDepth, callback)
		-- DEBUG: print(source .. ', ' .. destination .. ', ' .. sDepth .. ', ' .. dDepth)
		
		-- Main backpack containers
		local mainItemCount = xeno.getContainerItemCount(0)
		local backpacks = {}
		for spot = 0, mainItemCount - 1 do
			local item = xeno.getContainerSpotData(0, spot)
			if xeno.isItemContainer(item.id) then
				backpacks[#backpacks+1] = spot
			end
		end

		-- Fail-safe for source containers
		-- checks if container matches main backpack (contents, name, not id)
		local sourceBackpack = backpacks[source]
		if source ~= 0 and sourceBackpack and sDepth ~= -1 and compareContainers(0, source) then
			fixContainerDepth(source, sourceBackpack, sDepth, function()
				resetContainerDepths(source, destination, -1, dDepth, callback)
			end)
			return
		end

		-- Fail-safe for destination containers
		-- checks if container matches main backpack (contents, name, not id)
		local destBackpack = backpacks[destination]
		if destination ~= 0 and destBackpack and dDepth ~= -1 and compareContainers(0, destination) then
			fixContainerDepth(destination, destBackpack, dDepth, function()
				resetContainerDepths(source, destination, sDepth, -1, callback)
			end)
			return
		end

		-- Go back in source container
		if sDepth > 0 then
			xeno.containerBack(source)
			setTimeout(function()
				resetContainerDepths(source, destination, sDepth-1, dDepth, callback)
			end, pingDelay(DELAY.CONTAINER_BACK))

		-- Go back in destination container
		elseif dDepth > 0 then
			xeno.containerBack(destination)
			setTimeout(function()
				resetContainerDepths(source, destination, sDepth, dDepth-1, callback)
			end, pingDelay(DELAY.CONTAINER_BACK))

		-- Return
		elseif callback then
			callback()
		end
	end

	local function containerMoveItems(options, callback)
		local fromContainer = options.src
		local toContainer = options.dest
		local toSlot = options.slot or 0

		local whiteList = options.items
		local blackList = options.ignore
		local itemFilter = options.filter

		local disableSourceCascade = options.disableSourceCascade or fromContainer == _backpacks['Main']
		local openWindow = options.openwindow -- open first destination cascade in new window

		local spotOffset = 0
		local sourceDepth = 0
		local destDepth = 0

		local moveItem = nil
		local watchContainerFullError = nil
		local onContainerFull = nil
		local moveInterval = nil
		local fullEvent = nil

		local moveCounts = {}
		local lastMove = {
			itemid = nil,
			count = nil
		}

		-- Registers the error watcher
		watchContainerFullError = function()
			return when(EVENT_ERROR, ERROR_CONTAINER_FULL, onContainerFull)
		end

		local item = nil

		-- Called to trigger a single item move
		moveItem = function(self)

			-- Amount of this stack to move (defaults to all)
			local moveStackCount = -1

			-- Remaining items
			local itemCount = xeno.getContainerItemCount(fromContainer)

			-- No items and cascade OR skipped all filled spots, stop entirely
			if itemCount == 0 or spotOffset >= itemCount then
				-- Kill moveInterval & fullEvent
				clearTimeout(self)
				clearWhen(EVENT_ERROR, fullEvent)
				-- Reset depths and finish
				resetContainerDepths(fromContainer, toContainer, sourceDepth, destDepth, function()
					callback(true)
				end)
				return
			end

			-- Das item
			item = xeno.getContainerSpotData(fromContainer, spotOffset)

			-- Cascade backpack, last slot of backpack
			if xeno.isItemContainer(item.id) and (spotOffset + 1 >= itemCount) then 
				-- Cascade source enabled, open it, update source depth, reset spot offset
				if not disableSourceCascade then
					sourceDepth = sourceDepth + 1
					spotOffset = 0
					xeno.containerUseItem(fromContainer, itemCount-1, true)
				else
					spotOffset = spotOffset + 1
				end
				return
			end

			-- Item is in blacklist, try next spot
			if blackList and blackList[item.id] then
				spotOffset = spotOffset + 1
				return
			end

			-- Item not in filter list, try next spot
			if whiteList and not whiteList[item.id] then
				spotOffset = spotOffset + 1
				return
			end

			-- Item filter is set, run function to test validity
			if itemFilter and not itemFilter(item) then
				spotOffset = spotOffset + 1
				return
			end

			-- Item list, and entry has a number (count) value
			if whiteList and whiteList[item.id] and type(whiteList[item.id]) == 'number' then
				-- Check if we've moved any of this item yet
				if not moveCounts[item.id] then
					moveCounts[item.id] = whiteList[item.id]
				end

				-- We don't need anymore of this item, skip
				if moveCounts[item.id] <= 0 then
					spotOffset = spotOffset + 1
					return
				end

				-- Now we know how much to move, don't go over the needed (smallest value)
				moveStackCount = math.min(item.count, moveCounts[item.id])

				-- Decrease needed (we'll reverse this if we fail)
				moveCounts[item.id] = moveCounts[item.id] - moveStackCount
			end

			-- Track last move
			lastMove.itemid = item.id
			lastMove.count = moveStackCount
			-- Move item to destination
			xeno.containerMoveItemToContainer(fromContainer, spotOffset, toContainer, toSlot, moveStackCount)
		end

		-- Triggered when the destination fills up
		onContainerFull = function()
			-- Check if we need to reverse a needed count
			if item and whiteList and lastMove.itemid and lastMove.count > -1 and moveCounts[lastMove.itemid] then
				moveCounts[item.id] = moveCounts[item.id] + lastMove.count
			end

			-- Pause moving items
			-- No need to kill fullEvent, it dies after one use
			clearTimeout(moveInterval)

			setTimeout(function()
				-- We weren't depositing into a backpack, no cascade available
				if not xeno.isItemContainer(xeno.getContainerSpotData(toContainer, toSlot).id) then
					-- Reset depths and finish
					resetContainerDepths(fromContainer, toContainer, sourceDepth, destDepth, function()
						callback(false)
					end)
					return
				end
				-- Open destination container
				xeno.containerUseItem(toContainer, toSlot, not openWindow)
				setTimeout(function()
					-- Update toContainer index if we opened in a new window
					if openWindow then
						toContainer = getLastContainer()
						-- Reset destination depth, since we're in a new destination
						destDepth = 0
					end

					-- Check if last item is a container
					local lastSlot = xeno.getContainerItemCount(toContainer) - 1
					local cascadeID = xeno.getContainerSpotData(toContainer, lastSlot).id
					if xeno.isItemContainer(cascadeID) then
						-- Found cascade backpack, update slot, update destination depth
						openWindow = false
						destDepth = destDepth + 1
						toSlot = lastSlot

						-- Re-register events
						moveInterval = setInterval(moveItem, DELAY.CONTAINER_MOVE_ITEM)
						fullEvent = watchContainerFullError()
						return
					end
					-- No cascade backpack, stop entirely
					-- Reset depths and finish
					resetContainerDepths(fromContainer, toContainer, sourceDepth, destDepth, function()
						callback(false)
					end)
					return
				end, pingDelay(DELAY.CONTAINER_USE_ITEM))
			end, DELAY.CONTAINER_MOVE_ITEM)
		end

		-- Begin moving
		moveInterval = setInterval(moveItem, DELAY.CONTAINER_MOVE_ITEM)
		-- Start watching for container full errors
		fullEvent = watchContainerFullError()
	end

	local function moveItems(containers, options, callback)
		local source = table.remove(containers)
		containerMoveItems({
			src = source,
			dest = options.dest,
			slot = options.slot,
			items = options.items,
			disableSourceCascade = options.disableSourceCascade,
			openwindow = options.openwindow
		}, function(success)
			-- Last container, finish
			if #containers == 0 then 
				callback()
			-- Recurse
			else
				moveItems(containers, options, callback)
			end
		end)
	end

	local function cleanContainers(destination, itemList, callback, shallow)
		-- Check all backpacks except for destination
		-- for items in the list and move them to the destination
		local containers = {}
		for i = 0, 15 do
			if i ~= destination and xeno.getContainerOpen(i) then
				containers[#containers+1] = i
			end
		end
		moveItems(containers, {
			dest = destination,
			slot = 0,
			items = itemList,
			-- Do not dig into the main backpack
			disableSourceCascade = shallow,
			openwindow = false
		}, function(success)
			if callback then
				callback()
			end
		end)
	end

	local function openMainBackpack(callback)
		-- Open
		local opened = xeno.slotUseItem(3)

		-- Wait for Main Backpack
		setTimeout(function()
			-- Success
			if opened > 0 then
				if _config['General']['Minimize-Main-BP'] then
					xeno.minimizeContainer(0)
				end
				callback(opened)
			-- Fail, recurse
			else
				openMainBackpack(callback)
			end
		end, pingDelay(DELAY.USE_EQUIPMENT))
	end

	local function resetContainers(minimize, callback)
		-- Close all containers
		for i = 0, 15 do
			xeno.closeContainer(i)
		end

		openMainBackpack(function()
			local backpacks = {}
			local function openChild(index)
				local spot = backpacks[index]
				local freeslot = getLastContainer() + 1
				-- Open child backpack
				xeno.containerUseItem(0, spot)
				-- Wait for child to open
				setTimeout(function()
					-- Minimize backpack
					xeno.minimizeContainer(freeslot)
					-- Open next child
					if #backpacks > index then
						openChild(index+1)
					-- Complete, main callback
					else
						callback()
					end
				end, pingDelay(DELAY.CONTAINER_USE_ITEM))
			end

			-- Loop through all items, add containers to list
			local itemcount = xeno.getContainerItemCount(0)
			for spot = 0, itemcount - 1 do
				local item = xeno.getContainerSpotData(0, spot)
				if xeno.isItemContainer(item.id) then
					backpacks[#backpacks+1] = spot
				end
			end

			-- Call openChild for every backpack
			openChild(1)
		end)
	end

	local function setupContainers(callback)
		local needGoldContainer = false
		local needPotionContainer = false
		local needRuneContainer = false
		local needAmmoContainer = false
		local needSuppliesContainer = false

		log('Setting up your backpacks, please wait...')
		local function finishSetup()
			log('Your backpacks have been setup. Do NOT rearrange containers!')
			callback()
		end

		-- Move items in main backpack to the correct backpacks
		local function organizeMainBackpack()
			local destinations = {}
			local itemLists = {}

			-- Create itemid list for each supply group
			for itemid, supply in pairs(_supplies) do
				-- Amulets and Rings always go in the Supplies backpack
				local name = supply.group
				if name == 'Amulet' or name == 'Ring' then
					name = 'Supplies'
				end
				-- Send to Main backpack list if it matches the index
				local backpack = _backpacks[name]
				if backpack then
					if backpack == _backpacks['Main'] then
						name = 'Main'
					end
					-- Init table if it doesn't exist
					if not itemLists[backpack] then
						itemLists[backpack] = {}
						-- Add backpack to index for easy iteration
						destinations[#destinations+1] = {name, backpack}
					end
					-- Add supply item to the list
					itemLists[backpack][itemid] = true
				end
			end

			local function moveItems(index)
				local backpack = destinations[index]

				-- Check if destination exists (no items to move)
				if not backpack then
					finishSetup()
					return
				end

				local backpackName = backpack[1]
				local destination = backpack[2]

				-- Get itemid list for this backpack
				local itemList = itemLists[destination]

				-- Clean all backpacks and move valid items to this backpack
				cleanContainers(destination, itemList, function(success)
					-- Proceed to next destination
					moveItems(index+1)
				end)
			end

			-- Move items to proper backpack, then finish
			if #destinations > 0 then
				moveItems(1)
			-- None to move, finish up
			else
				finishSetup()
			end
		end

		-- Assign backpacks
		local function assignBackpacks()
			-- Setup containers (start at index 2 since Main = 0, Loot = 1)
			local index = 2
			local list = {}

			list[#list+1] = '1  -  Main backpack'
			list[#list+1] = '2  -  Loot backpack'

			local containerStatuses = {
				{'Gold', needGoldContainer},
				{'Potions', needPotionContainer},
				{'Runes', needRuneContainer},
				{'Ammo', needAmmoContainer},
				{'Supplies', needSuppliesContainer}
			}

			for i = 1, #containerStatuses do
				local status = containerStatuses[i]
				if status and status[2] then
					_backpacks[status[1]] = index
					list[#list+1] = ('%d  -  %s backpack'):format(index+1, status[1])
					index = index + 1
				else
					_backpacks[status[1]] = 0
				end
			end

			info('Your backpack setup:\n' .. formatList(list, '\n', '    '));
			log('Organizing your backpacks, please wait...')
			organizeMainBackpack()
		end

		-- Open main bp and children
		resetContainers(true, function()
			-- Count how many are open (excluding main bp)
			-- Determine how many we need
			-- If we have enough, continue
			-- If not, prompt user, wait for response, recheck

			-- Loop through supplies, flag each "type" of container we will need
			local neededContainers = 0
			local runeCount = 0
			local potionCount = 0
			local ammoCount = 0
			local supplyCount = 0

			if _config['Loot']['Loot-Gold'] then
			   neededContainers = neededContainers + 1
			   needGoldContainer = true 
			end

			for supplyId, supply in pairs(_supplies) do
				if supply.group == 'Potions' and not needPotionContainer then
					potionCount = potionCount + supply.max
					if potionCount > 100 then
						neededContainers = neededContainers + 1
						needPotionContainer = true
					end
				elseif supply.group == 'Runes' and not needRuneContainer then
					runeCount = runeCount + supply.max
					if runeCount > 100 then
						neededContainers = neededContainers + 1
						needRuneContainer = true
					end
				elseif supply.group == 'Ammo' and not needAmmoContainer then
					ammoCount = ammoCount + supply.max
					if ammoCount > 100 then
						neededContainers = neededContainers + 1
						needAmmoContainer = true
					end
				elseif (supply.group == 'Ring' or supply.group == 'Amulet') and not needSuppliesContainer then
					supplyCount = supplyCount + supply.max
					if supplyCount > 5 then
						neededContainers = neededContainers + 1
						needSuppliesContainer = true
					end
				end
			end

			-- Backpacks inside main bp we can use (ignore mainbp and loot bp)
			local availableContainers = getLastContainer() - 1

			-- Make sure we have enough, if not prompt, then retry
			if availableContainers < neededContainers then
				-- prompt user, then assignBackpacks
				local missingCount = (neededContainers - availableContainers)
				local singularMsg = 'Not enough backpacks. Add one more backpack to your main backpack. Type "retry" to continue.'
				local pluralMsg = 'Not enough backpacks. Add ' .. missingCount .. ' more backpacks to your main backpack. Type "retry" to continue.'
				local message = missingCount > 1 and pluralMsg or singularMsg
				local function promptBackpacks()
					prompt(message, function(response)
						if string.find(string.lower(response), 'retry') then
							setupContainers(callback)
						else
							promptBackpacks()
						end
					end)
				end
				promptBackpacks()
				return
			end

			-- All is well, start setup
			assignBackpacks()
		end)
	end

	local function getContainerItemCounts(index, callback, deepSearch, startLevel)
		local items = {}
		local function countLevel(level)
			-- Iterate through container spots
			for spot = 0, xeno.getContainerItemCount(index) - 1 do
				local item = xeno.getContainerSpotData(index, spot)
				-- Create table and entries on-demand
				if not items[item.id] then
					items[item.id] = 0
				end
				-- Increment count
				items[item.id] = items[item.id] + math.max(item.count, 1)
			end

			-- Only counting the current container level OR reached top level
			if not deepSearch or level <= 1 then
				if callback then
					callback(items)
				end
				return items
			-- Not done, keep counting backwards
			else
				-- Navigate back a level
				local ret = xeno.containerBack(index)
				-- Failed to go back
				if ret == 0 then
					if callback then
						callback(items)
					end
				-- Count new level
				else
					setTimeout(function()
						countLevel(level-1)
					end, pingDelay(DELAY.CONTAINER_BACK))
				end
			end
			return nil
		end
		local function gotoBottom(depth)
			local lastSlot = xeno.getContainerItemCount(index) - 1
			local cascadeID = xeno.getContainerSpotData(index, lastSlot).id
			-- Another cascade, go deeper
			if xeno.isItemContainer(cascadeID) then
				xeno.containerUseItem(index, lastSlot, true)
				setTimeout(function()
					gotoBottom(depth + 1)
				end, pingDelay(DELAY.CONTAINER_USE_ITEM))
				return
			end
			-- At the last level, start counting items
			countLevel(depth)
		end
		-- Deep count specified, go to end of container and count backwards
		if deepSearch then
			gotoBottom(startLevel or 1)
		-- Shallow count, function can be used synchronously
		else
			return countLevel(1)
		end
	end

	local function getTotalItemCount(itemIdList, ignoreEquipment)
		local totals = {}

		-- Wrap single itemid in an index table
		if type(itemIdList) ~= 'table' then
			itemIdList = {[itemIdList] = true}
		end

		-- Count equipment
		if not ignoreEquipment then
			local slots = {
				xeno.getHeadSlotData,
				xeno.getArmorSlotData,
				xeno.getLegsSlotData,
				xeno.getFeetSlotData,
				xeno.getAmuletSlotData,
				xeno.getWeaponSlotData,
				xeno.getRingSlotData,
				xeno.getShieldSlotData,
				xeno.getAmmoSlotData
			}
			for i = 1, #slots do -- count slots
				local slot = slots[i]()
				if itemIdList[slot.id] then
					total = total + math.max(slot.count, 1)
				end
			end
		end

		-- Iterate all possible containers
		for i = 0, 16 do
			-- No more containers, stop searching
			if not xeno.getContainerOpen(i) then
				break
			end
			-- Count this container
			local counts = getContainerItemCounts(i)
			for itemid, itemcount in pairs(counts) do
				-- Counting this item
				if itemIdList[itemid] then
					local itemTotal = totals[itemid]
					if not itemTotal then
						totals[itemid] = itemcount
					else
						itemTotal = itemTotal + itemcount
					end
				end
			end
		end

		-- Pairs table with itemid = count
		return totals
	end

	local function getMoney()
		local counts = getTotalItemCount(ITEM_LIST_MONEY)

		local gold = counts[3031] or 0
		local plat = counts[3035] or 0
		local crystal = counts[3043] or 0

		local total = gold
		total = total + (plat * 100)
		total = total + (crystal * 10000)

		return total
	end

	local function getFlasks()
		local counts = getTotalItemCount(ITEM_LIST_FLASKS)

		local small = counts[285] or 0
		local med = counts[284] or 0
		local large = counts[283] or 0

		return small + med + large
	end

	local function unrustLoot(callback)
		-- Make sure a corpse is not currently open
		-- Loop through each slot in the loot container
		-- If loot is a "rusty" item, use oil on it.
		-- Wait x delay and look at the same slot.
		-- If loot is shitty, toss it out. (offset slot in loop)
		-- If loot is good, continue (add to supplies)
		-- Remove rusty armor from supplies (HUD)
		-- Add oil as supply waste (HUD)
	end

	-- Export global functions
	return {
		getLastContainer = getLastContainer,
		getContainerByName = getContainerByName,
		containerMoveItems = containerMoveItems,
		setupContainers = setupContainers,
		resetContainers = resetContainers,
		getContainerItemCounts = getContainerItemCounts,
		cleanContainers = cleanContainers,
		getTotalItemCount = getTotalItemCount,
		getMoney = getMoney,
		getFlasks = getFlasks
	}
end)()