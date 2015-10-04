Ini = (function()
	-- Imports
	local split = Core.split
	local trim = Core.trim
	local setTimeout = Core.setTimeout
	local getSelfName = Core.getSelfName
	local error = Console.error

	local function updateSupplyConfig()
		local function loadBlockSection(sectionName, extras)
			local section = _config[sectionName]
			if section then
				for key, value in pairs(section) do
					local start, stop = string.find(key, 'Name')
					if start and value then
						-- Base name of the key (ex: 'Mana' of 'ManaName')
						local name = string.sub(key, 1, start-1)
						local enabled = section[name .. 'Enabled']
						-- Supply is enabled
						if enabled ~= false then
							-- TODO: validate user submitted name/id
							local id = nil
							if sectionName == 'Spells' then
								id = string.lower(value)
							else
								id = type(value) == 'string' and xeno.getItemIDByName(value) or tonumber(value)
							end

							local min = section[name .. 'Min'] or 0
							local max = section[name .. 'Max'] or 0

							-- Noob proofing
							if min > max then
								error('Config error. The "' .. name .. 'Min" value is higher than the "' .. name .. 'Max" value.')
							end

							local alarm = section[name .. 'Alarm'] or 0
							local options = nil

							-- Extra fields
							if extras then
								options = {}
								for i = 1, #extras do
									local extraKey = extras[i]
									local extraValue = section[name .. extraKey]
									if extraValue ~= nil then
										options[extraKey] = extraValue
									end
								end
							end

							-- Add item to supplies list
							_supplies[id] = {
								name = name,
								id = id,
								group = sectionName,
								count = 0,
								needed = 0,
								min = min,
								max = max,
								alarm = alarm,
								options = options
							}
						end
					end
				end
			end
		end

		loadBlockSection('Potions')
		loadBlockSection('Ammo')
		loadBlockSection('Food')
		loadBlockSection('Supplies')
		loadBlockSection('Runes', {'Priority', 'TargetMin', 'Targets'})
		loadBlockSection('Spells', {'Priority', 'TargetMin', 'Targets'})
		loadBlockSection('Ring', {'Creature-Equip', 'Health-Equip', 'Mana-Equip'})
		loadBlockSection('Amulet', {'Creature-Equip', 'Health-Equip', 'Mana-Equip'})
	end

	local function loadConfigFile(callback, isReload)
		local configPath = FOLDER_CONFIG_PATH .. '[' .. getSelfName() .. '] ' .. _script.name .. '.ini'
		local configAltPath = FOLDER_CONFIG_PATH .. 'Config\\[' .. getSelfName() .. '] ' .. _script.name .. '.ini'
		local function parseConfig(file)
			-- Could not load config
			if not file then
				error('Could not load the config.')
			end

			local tbl = {}
			local section
			for line in file:lines() do
				local s = string.match(line, "^%[([^%]]+)%]$")
				if s then
					section = s
					tbl[section] = tbl[section] or {}
				end
				local key, value = string.match(line, "^([^%s]+)%s+=%s+([^;]+)")
				if key and value then
					-- Type casting
					if tonumber(value) ~= nil then
						value = tonumber(value)
					else
						value = string.gsub(value, "^%s*(.-)%s*$", "%1")
						if value == "true" then
							value = true
						elseif value == "false" then
							value = false
						-- Transform comma-delimited string to table
						elseif string.find(value, ',') then
							value = split(value, ',')
							for i = 1, #value do
								value[i] = trim(value[i])
							end
						end
					end
					if section then
						if not tbl[section] then
							tbl[section] = {}
						end
						tbl[section][key] = value
					end
				end
			end

			-- Adjust specific config options

			-- Convert lure creatures to key,value table
			if tbl['Lure'] then
				local lureCreatures = tbl['Lure']['Creatures']
				if lureCreatures then
					local lureTbl = {}
					if type(lureCreatures) == 'table' then
						for i = 1, #lureCreatures do
							lureTbl[string.lower(lureCreatures[i])] = true
						end
						tbl['Lure']['Creatures'] = lureTbl
					else
						tbl['Lure']['Creatures'] = {
							[string.lower(lureCreatures)] = true 
						}
					end
				end
			end

			-- Convert anti-lure creatures to key,value table
			if tbl['Anti Lure'] then
				local lureCreatures = tbl['Anti Lure']['Creatures']
				if lureCreatures then
					local lureTbl = {}
					if type(lureCreatures) == 'table' then
						for i = 1, #lureCreatures do
							lureTbl[string.lower(lureCreatures[i])] = true
						end
						tbl['Anti Lure']['Creatures'] = lureTbl
					else
						tbl['Anti Lure']['Creatures'] = {
							[string.lower(lureCreatures)] = true 
						}
					end
				end
			end

			-- Update start config values
			if not isReload and tbl['HUD'] then
				_script.theme = tbl['HUD']['Theme'] or 'light'
			end

			file:close()
			_config = tbl
			updateSupplyConfig()
			callback()
		end

		-- Could not load config, try to write default
		local file = io.open(configPath, 'r')
		if not file then
			-- Look in alt location (Config folder)
			file = io.open(configAltPath, 'r')
			if not file then
				local defaultConfig = io.open(configPath, 'w+')
				if defaultConfig then
					defaultConfig:write(LIB_CONFIG)
					defaultConfig:close()
					setTimeout(function()
						local newFile = io.open(configPath, 'r')
						parseConfig(newFile)
					end, 1000)
				else
					error('Could not write default config.')
				end
			else
				parseConfig(file)
			end
		else
			parseConfig(file)
		end
	end

	-- Export global functions
	return {
		loadConfigFile = loadConfigFile
	}
end)()
