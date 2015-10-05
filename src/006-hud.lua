Hud = (function()
	
	-- Imports
	local formatNumber = Core.formatNumber
	local overflowText = Core.overflowText
	local titlecase = Core.titlecase
	local isCorpseOpen = Core.isCorpseOpen

	local function hudUpdateDimensions()
		local screen = xeno.HUDGetDimensions()
		local changed = _hud.gamewindow.x ~= screen.gamewindowx or
						_hud.gamewindow.y ~= screen.gamewindowy or
						_hud.gamewindow.w ~= screen.gamewindoww or
						_hud.gamewindow.h ~= screen.gamewindowh

		if not changed and _hud.rightcolumn.x > 0 then
			return false
		end

		_hud.gamewindow = {
			x = screen.gamewindowx,
			y = screen.gamewindowy,
			w = screen.gamewindoww,
			h = screen.gamewindowh
		}

		_hud.rightcolumn.x = screen.gamewindowx + screen.gamewindoww + 10

		return true
	end

	local function hudUpdatePositions()
		-- Reposition columns
		local leftcolumn = _hud.leftcolumn
		local rightcolumn = _hud.rightcolumn

		-- Threshold for y-axis (before wrapping)
		local maxAxisY = (_hud.gamewindow.y + _hud.gamewindow.h) - 10
		local wrappedColumn = false

		-- Track our current position while we add/update
		local currentAxisY = leftcolumn.y
		local currentAxisX = leftcolumn.x

		-- Loop through all panels in the column
		for i = 1, #leftcolumn.panels do
			-- Track the total height the panels take up
			local panel = leftcolumn.panels[i]
			local itemCount = #panel.items

			-- If panel has items we show the title of the panel
			-- add 25 pixels to the y-axis for the title (after adding/re-positioning the title)
			if itemCount > 0 then
				-- Detect if at least 1 item can fit on the screen
				-- if not, wrap the entire panel (including title)
				if currentAxisY + 20 > maxAxisY then
					currentAxisY = leftcolumn.y
					currentAxisX = currentAxisX + leftcolumn.w
				end

				-- Add panel title if it doesn't yet exist
				if not panel.pointer then
					leftcolumn.panels[i].pointer = xeno.HUDCreateText(currentAxisX, currentAxisY, '[' .. panel.title .. ']', unpack(THEME[_script.theme].title))
				-- Update position
				else
					xeno.HUDUpdateLocation(panel.pointer, currentAxisX, currentAxisY)
				end
				currentAxisY = currentAxisY + 20

				-- Look at first item, if value is a number, sort all items higher to lower
				if type(panel.items[1].value) == 'number' then
					table.sort(panel.items, function(a, b)
						return a.value > b.value
					end)
				end
			end

			-- Loop through all items in the panel
			local wrappedPanel = false
			for j = 1, itemCount do
				-- Add or update title & value
				local item = panel.items[j]

				-- Add item title if pointer doesn't exist
				if not item.tpointer then
					local itemTitle = item.title .. ':'
					-- Title is an item id
					if type(item.title) == 'number' then
						itemTitle = overflowText(titlecase(xeno.getItemNameByID(item.title)), 11, '...')
						-- Icon doesn't exist, add it
						if not item.ipointer then
							-- Only add an icon if they are enabled
							if _config['HUD']['Show-Icons'] then
								-- Images need slight y-axis offset
								panel.items[j].ipointer = xeno.HUDCreateItemImage(currentAxisX, currentAxisY-5, item.title, 16, 100)
							end
						-- Update icon position (even if disabled, since we can't destroy them)
						else
							xeno.HUDUpdateLocation(item.ipointer, currentAxisX, currentAxisY-5)
						end
					end
					-- Indent title if there's an icon
					local xOffset = item.ipointer and 25 or 0
					panel.items[j].tpointer = xeno.HUDCreateText(currentAxisX + xOffset, currentAxisY, itemTitle, unpack(THEME[_script.theme].primary))
				-- Update item title position
				else
					-- Update icon position (even if disabled, since we can't destroy them)
					if item.ipointer then
						xeno.HUDUpdateLocation(item.ipointer, currentAxisX, currentAxisY-5)
					end
					local xOffset = item.ipointer and 25 or 0
					xeno.HUDUpdateLocation(item.tpointer, currentAxisX + xOffset, currentAxisY)
				end

				-- Add item value if pointer doesn't exist
				if not item.vpointer then
					local itemValue = item.value
					if type(item.value) == 'number' then
						itemValue = formatNumber(item.value) .. ' gp'
					end
					panel.items[j].vpointer = xeno.HUDCreateText(currentAxisX + 110, currentAxisY, itemValue, unpack(THEME[_script.theme].secondary))
				-- Update item value position
				else
					xeno.HUDUpdateLocation(item.vpointer, currentAxisX + 110, currentAxisY)
				end

				-- Each items adds 25px to the y-axis
				currentAxisY = currentAxisY + 15

				-- Test if we need to wrap the column
				if not wrappedColumn and currentAxisY >= maxAxisY then
					-- Reset y-axis (from panel title)
					currentAxisY = leftcolumn.y + 20
					-- Wrap to next "column"
					currentAxisX = currentAxisX + leftcolumn.w
					-- Flag as we wrapped once, do not show anymore panels
					wrappedPanel = true
				end
			end

			-- Wrapped items in the panel, flag the column as wrapped
			if wrappedPanel then
				wrappedColumn = true
			end

			-- Add padding to bottom if there were items
			if itemCount > 0 then
				currentAxisY = currentAxisY + 15
			end

			-- Wrapped the last panel (hide the rest)
			if wrappedColumn then
				currentAxisX = currentAxisX - (leftcolumn.w * 2)
			end
		end

		-- Track our current position while we add/update
		currentAxisY = rightcolumn.y
		currentAxisX = rightcolumn.x

		-- Loop through all panels in the column
		for i = 1, #rightcolumn.panels do
			-- Track the total height the panels take up
			local panel = rightcolumn.panels[i]
			local itemCount = #panel.items

			-- If panel has items we show the title of the panel
			-- add 25 pixels to the y-axis for the title (after adding/re-positioning the title)
			if itemCount > 0 then
				-- Detect if at least 1 item can fit on the screen
				-- if not, wrap the entire panel (including title)
				if currentAxisY + 20 > maxAxisY then
					currentAxisY = rightcolumn.y
					currentAxisX = currentAxisX + rightcolumn.w
				end

				-- Add panel title if it doesn't yet exist
				if not panel.pointer then
					rightcolumn.panels[i].pointer = xeno.HUDCreateText(currentAxisX, currentAxisY, '[' .. panel.title .. ']', unpack(THEME[_script.theme].title))
				-- Update position
				else
					xeno.HUDUpdateLocation(panel.pointer, currentAxisX, currentAxisY)
				end
				currentAxisY = currentAxisY + 20

				-- Look at first item, if value is a number, sort all items higher to lower
				if type(panel.items[1].value) == 'number' then
					table.sort(panel.items, function(a, b)
						return a.value > b.value
					end)
				end
			end

			-- Loop through all items in the panel
			local wrappedPanel = false
			for j = 1, itemCount do
				-- Add or update title & value
				local item = panel.items[j]

				-- Add item title if pointer doesn't exist
				if not item.tpointer then
					local itemTitle = item.title .. ':'
					-- Title is an item id
					if type(item.title) == 'number' then
						itemTitle = overflowText(titlecase(xeno.getItemNameByID(item.title)), 11, '...')
						-- Icon doesn't exist, add it
						if not item.ipointer then
							-- Only add an icon if they are enabled
							if _config['HUD']['Show-Icons'] then
								-- Images need slight y-axis offset
								panel.items[j].ipointer = xeno.HUDCreateItemImage(currentAxisX, currentAxisY-5, item.title, 16, 100)
							end
						-- Update icon position (even if disabled, since we can't destroy them)
						else
							xeno.HUDUpdateLocation(item.ipointer, currentAxisX, currentAxisY-5)
						end
					end
					-- Indent title if there's an icon
					local xOffset = item.ipointer and 25 or 0
					panel.items[j].tpointer = xeno.HUDCreateText(currentAxisX + xOffset, currentAxisY, itemTitle, unpack(THEME[_script.theme].primary))
				-- Update item title position
				else
					-- Update icon position (even if disabled, since we can't destroy them)
					if item.ipointer then
						xeno.HUDUpdateLocation(item.ipointer, currentAxisX, currentAxisY-5)
					end
					local xOffset = item.ipointer and 25 or 0
					xeno.HUDUpdateLocation(item.tpointer, currentAxisX + xOffset, currentAxisY)
				end

				-- Add item value if pointer doesn't exist
				if not item.vpointer then
					local itemValue = item.value
					if type(item.value) == 'number' then
						itemValue = formatNumber(item.value) .. ' gp'
					end
					panel.items[j].vpointer = xeno.HUDCreateText(currentAxisX + 110, currentAxisY, itemValue, unpack(THEME[_script.theme].secondary))
				-- Update item value position
				else
					xeno.HUDUpdateLocation(item.vpointer, currentAxisX + 110, currentAxisY)
				end

				-- Each items adds 25px to the y-axis
				currentAxisY = currentAxisY + 15

				-- Test if we need to wrap the column
				if not wrappedColumn and currentAxisY >= maxAxisY then
					-- Reset y-axis (from panel title)
					currentAxisY = rightcolumn.y + 20
					-- Wrap to next "column"
					currentAxisX = currentAxisX + rightcolumn.w
					-- Flag as we wrapped once, do not show anymore panels
					wrappedPanel = true
				end
			end

			-- Wrapped items in the panel, flag the column as wrapped
			if wrappedPanel then
				wrappedColumn = true
			end

			-- Add padding to bottom if there were items
			if itemCount > 0 then
				currentAxisY = currentAxisY + 15
			end

			-- Wrapped the last panel (hide the rest)
			if wrappedColumn then
				currentAxisX = currentAxisX - (rightcolumn.w * 2)
			end
		end
	end

	local function hudPanelCreate(title, column, skipUpdate)
		local panel = {
			title = title,
			items = {}
		}
		table.insert(_hud[column].panels, panel)
		if not skipUpdate then
			hudUpdatePositions()
		end
		_hud.index[title] = panel
		return panel
	end

	local function hudItemCreate(panel, title, value, skipUpdate)
		local panel = _hud.index[panel]
		if not panel then
			return false
		end

		local item = {
			title = title,
			value = value
		}
		table.insert(panel.items, item)
		if not skipUpdate then
			hudUpdatePositions()
		end
		_hud.index[panel.title][title] = item
		return item
	end

	local function hudItemUpdate(panel, title, value, skipUpdate)
		local panel = _hud.index[panel]
		if panel then
			local item = panel[title]
			if item and value ~= item.value then
				item.value = value
				local itemValue = value
				if type(value) == 'number' then
					itemValue = formatNumber(value) .. ' gp'
				end
				xeno.HUDUpdateTextText(item.vpointer, itemValue)
				if not skipUpdate then
					hudUpdatePositions()
				end
			end
		end
	end

	local function hudQueryLootChanges()
		-- Only check loot changes when there is a corpse open
		-- TODO: support fishing/skinning
		local corpseOpen = isCorpseOpen()

		-- Total value from this query
		local totalQueryValue = 0

		local function queryBackpackChanges(type, filter)
			-- Check looted items (if not main bp)
			if _backpacks[type] and _backpacks[type] > 0 then
				-- Create snapshot if doesn't exist
				if not _hud.lootSnapshots[type] then
					_hud.lootSnapshots[type] = {}
				end

				-- Count the items in the backpack
				local newCounts = {}
				for spot = 0, xeno.getContainerItemCount(_backpacks[type]) - 1 do
					local item = xeno.getContainerSpotData(_backpacks[type], spot)
					-- Only look at items in list
					if not filter or filter[item.id] then
						-- Initialize the count if needed
						if not newCounts[item.id] then
							newCounts[item.id] = 0
						end
						-- Increment the count
						newCounts[item.id] = newCounts[item.id] + math.max(1, item.count)
					end
				end

				-- Find out which items went missing (none found and were there before)
				for lootID, lootCount in pairs(_hud.lootSnapshots[type]) do
					if not newCounts[lootID] then
						_hud.lootSnapshots[type][lootID] = 0
					end
				end

				-- Loop through all itemids with new counts
				for lootID, lootCount in pairs(newCounts) do
					-- No snapshot, set to zero
					if not _hud.lootSnapshots[type][lootID] then
						_hud.lootSnapshots[type][lootID] = 0
					end
					-- Get difference of snapshot and new count
					local difference = lootCount - _hud.lootSnapshots[type][lootID]
					-- Snapshot current count (even without corpse)
					_hud.lootSnapshots[type][lootID] = lootCount
					-- If difference is positive and corpse open, add to totals
					if difference > 0 and corpseOpen then
						local value = (xeno.getItemValue(lootID) * difference)
						-- Add to overall total
						totalQueryValue = totalQueryValue + value
						-- Initialize specific loot in HUD if needed
						if not _hud.index['Loot'][lootID] then
							hudItemCreate('Loot', lootID, 0, false)
						end
						-- Get current count and values
						local hudCount = (_hud.index['Loot'][lootID].rawCount or 0) + difference
						local hudValue = (_hud.index['Loot'][lootID].rawValue or 0) + value
						-- Save values
						_hud.index['Loot'][lootID].rawCount = hudCount
						_hud.index['Loot'][lootID].rawValue = hudValue
						-- Only show value for money
						local displayText = ''
						if ITEM_LIST_MONEY[lootID] then
							displayText = formatNumber(hudValue) .. ' gp'
						-- Everything else shows value and count
						else
							displayText = formatNumber(hudCount) .. ' (' .. formatNumber(hudValue) .. ' gp)'
						end
						-- Display values
						hudItemUpdate('Loot', lootID, displayText, false)
					end
				end
			end
		end

		queryBackpackChanges('Gold', ITEM_LIST_MONEY)
		queryBackpackChanges('Loot')

		if totalQueryValue > 0 then
			-- Update looted total
			local totalLooted = _hud.index['Statistics']['Looted'].value
			local totalWaste = _hud.index['Statistics']['Wasted'].value
			hudItemUpdate('Statistics', 'Looted', totalLooted + totalQueryValue, true)
			-- Update profit
			local gain = (totalLooted + totalQueryValue) - totalWaste
			local timediff = os.time() - _script.start
			local hourlygain = tonumber(math.floor(gain / (timediff / 3600))) or 0
			hudItemUpdate('Statistics', 'Profit', formatNumber(hourlygain) .. ' gp/h', false)
			-- Update HUD
			hudUpdatePositions()
		end
	end

	local function hudQuerySupplyChanges()
		-- Total value from this query
		local totalQueryValue = 0

		local function queryBackpackChanges(type, filter)
			-- Check supply items, skip if closed
			if _backpacks[type] and xeno.getContainerOpen(_backpacks[type]) then
				-- Create snapshot if doesn't exist
				if not _hud.supplySnapshots[type] then
					_hud.supplySnapshots[type] = {}
				end

				-- Count the items in the backpack
				local newCounts = {}
				for spot = 0, xeno.getContainerItemCount(_backpacks[type]) - 1 do
					local item = xeno.getContainerSpotData(_backpacks[type], spot)
					-- Only look at items in list
					if not filter or filter[item.id] then
						-- Initialize the count if needed
						if not newCounts[item.id] then
							newCounts[item.id] = 0
						end
						-- Increment the count
						newCounts[item.id] = newCounts[item.id] + math.max(1, item.count)
					end
				end

				-- Find out which items went missing (none found and were there before)
				for supplyID, supplyCount in pairs(_hud.supplySnapshots[type]) do
					if not newCounts[supplyID] then
						-- This differs from the loot tracking,
						-- instead of clearing the snapshot, we set the newCount to 0, so we get a negative
						newCounts[supplyID] = 0
					end
				end

				-- Loop through all itemids with new counts
				for supplyID, supplyCount in pairs(newCounts) do
					-- No snapshot, set to zero
					if not _hud.supplySnapshots[type][supplyID] then
						_hud.supplySnapshots[type][supplyID] = 0
					end
					-- Get difference of snapshot and new count
					local difference = supplyCount - _hud.supplySnapshots[type][supplyID]
					-- Snapshot current count (even when gaining supplies)
					_hud.supplySnapshots[type][supplyID] = supplyCount
					-- If difference is negative AND depot is not open, add to totals
					if difference < 0 and not _script.depotOpen then
						-- Only the absolute value matters at this point
						difference = math.abs(difference)
						local value = xeno.getItemCost(supplyID) * difference
						-- Add to overall total
						totalQueryValue = totalQueryValue + value
						-- Initialize specific loot in HUD if needed
						if not _hud.index['Supplies'][supplyID] then
							hudItemCreate('Supplies', supplyID, 0, false)
						end
						-- Get current count and values
						local hudCount = (_hud.index['Supplies'][supplyID].rawCount or 0) + difference
						local hudValue = (_hud.index['Supplies'][supplyID].rawValue or 0) + value
						-- Save values
						_hud.index['Supplies'][supplyID].rawCount = hudCount
						_hud.index['Supplies'][supplyID].rawValue = hudValue
						-- Only show value for money
						-- TODO: display and track duration items differently
						local displayText = ''
						displayText = formatNumber(hudCount) .. ' (' .. formatNumber(hudValue) .. ' gp)'
						-- Display values
						hudItemUpdate('Supplies', supplyID, displayText, false)
					end
				end
			end

			-- TODO: Look for items in the equipment slot that decreased from the container
			-- decrease the missing count by the slot count
		end

		-- Populate backpack and item lists to check changes
		local supplyLists = {}
		for itemid, supply in pairs(_supplies) do
			-- Amulets and Rings always go in the Supplies backpack
			local name = supply.group
			if name == 'Amulet' or name == 'Ring' then
				name = 'Supplies'
			end
			-- Send to Main backpack list if it matches the index
			local backpack = _backpacks[name]
			if backpack == _backpacks['Main'] then
				name = 'Main'
			end
			-- Init table if it doesn't exist
			if not supplyLists[name] then
				supplyLists[name] = {}
			end
			-- Add supply item to the list
			supplyLists[name][itemid] = true
		end

		for backpack, filter in pairs(supplyLists) do
			queryBackpackChanges(backpack, filter)
		end

		if totalQueryValue > 0 then
			-- Update supply total
			local totalWaste = _hud.index['Statistics']['Wasted'].value
			local totalLooted = _hud.index['Statistics']['Looted'].value
			hudItemUpdate('Statistics', 'Wasted', totalWaste + totalQueryValue, true)
			-- Update profit
			local gain = totalLooted - (totalWaste + totalQueryValue)
			local timediff = os.time() - _script.start
			local hourlygain = tonumber(math.floor(gain / (timediff / 3600))) or 0
			hudItemUpdate('Statistics', 'Profit', formatNumber(hourlygain) .. ' gp/h', false)
		end
	end

	local function hudInit()
		hudPanelCreate('General', 'leftcolumn', true)
		hudPanelCreate('Statistics', 'leftcolumn', true)
		hudPanelCreate('Script', 'leftcolumn', true)

		hudPanelCreate('Supplies', 'rightcolumn', true)
		hudPanelCreate('Loot', 'rightcolumn', true)

		hudItemCreate('General', 'Online Time', '--', true)
		hudItemCreate('General', 'Time Remaining', '--', true)
		hudItemCreate('General', 'Server Save', '--', true)
		hudItemCreate('General', 'Stamina', '--', true)
		hudItemCreate('General', 'Latency', '--', true)
		hudItemCreate('General', 'Balance', '--', true)

		hudItemCreate('Script', 'State', 'Starting', true)
		hudItemCreate('Script', 'Route', '--', true)
		--hudItemCreate('Script', 'Avg. Resupply', '--', true)
		--hudItemCreate('Script', 'Avg. Round', '--', true)

		hudItemCreate('Statistics', 'Experience', '--', true)
		hudItemCreate('Statistics', 'Profit', '--', true)
		hudItemCreate('Statistics', 'Looted', 0, true)
		hudItemCreate('Statistics', 'Wasted', 0, true)
		hudUpdatePositions()
	end

	-- Export global functions
	return {
		hudUpdateDimensions = hudUpdateDimensions,
		hudUpdatePositions = hudUpdatePositions,
		hudItemUpdate = hudItemUpdate,
		hudQueryLootChanges = hudQueryLootChanges,
		hudQuerySupplyChanges = hudQuerySupplyChanges,
		hudInit = hudInit
	}
end)()