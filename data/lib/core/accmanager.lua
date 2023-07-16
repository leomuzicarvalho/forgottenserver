---------------------------------------------------------------
--						ONLY EDIT HERE !					 --
---------------------------------------------------------------
accountManagerConfig =
{
	enabled = true, -- true = You can use the account manager, false = You cannot use the account manager.
	maxCharacters = 10, -- means how much characters each account can have at max.
	kickWithSameIP = true, -- false = if there are more account managers online with the same IP it wont kick them, true = It'll allow only a set ammount of account managers to be logged in with the same IP at once.
	kickAtAmmount = 2, -- this only take in place if "kickWithSameIP" = true; 2 = only two account managers can be logged in with the same IP at once.
	canchooseVoc = true, -- true = your player can choose which voc he wants for his char (start at lvl 8), false = you have no voc and start at lvl 1.
	townID = 1, -- which town the player will be at first login.
	blockedNames = {"GM","GOD","CM","Community Manager","Tutor"}, -- insert all patterns in here for names which you find not appropriate.
	voc = -- put all the starting vocations in here, with the correct id of them.
	{
		[1] = "sorcerer",
		[2] = "druid",
		[3] = "paladin",
		[4] = "knight"
	},
	startDest = -- destination where the account manager spawns at (I recommend a place where he is alone and no other players can go to)
	{
		x = 880,
		y = 1440,
		z = 7
	},
	gender = -- put in here if you have more genders (sex) in your server.
	{
		[0] = "female",
		[1] = "male"
	}
}
---------------------------------------------------------------
---------------------------------------------------------------

AccountManager = {
	__index = AccountManager,
	existingAccountNames = {},
	existingCharacterNames = {},
	encryptionKey = {}
}

setmetatable(AccountManager, {
	__call = 
	function(self, id)
		if not self[id] then
			self[id] = {__index = AccountManager, __gc = function(self, id) print("collected Account Class: ".. id) end, state = 0}
			setmetatable(self[id], self[id])
			return self[id]
		else
			return self[id]
		end
	end,
	__gc = 
	function(self, id) 
		print("collected Account Class: ".. id) 
	end
})

function Player.sendTextToClient(self, text, author, channelId, chType)
	local network = NetworkMessage()
	network:addByte(0xAA)
	network:addU32(0x00)
	network:addString(author)
	network:addU16(0x00)
	network:addByte(chType)
	network:addU16(channelId)
	network:addString(text)
	network:sendToPlayer(self)
	network:reset()
end

function Player.sendTextToLocalChat(self, mClass, text)
	local network = NetworkMessage()
	network:addByte(0xB4)
	network:addByte(mClass)
	network:addString(text)
	network:sendToPlayer(self)
	network:reset()
end

function Player.checkCharacterListSize(self)
	local res = db.storeQuery("SELECT `account_id` FROM `players` WHERE `name` = '".. self:getName() .."'")
	if res then
		accId = result.getDataInt(res, "account_id")
	end
	result.free(res)
	local res = db.storeQuery("SELECT COUNT(*) as row FROM `players` WHERE `account_id` = ".. accId .."")
	if res then
		count = result.getDataInt(res, "row")
	end
	result.free(res)
	return count
end

function generateEncryptionKey()
	local key = {}
	repeat
		local n = math.random(string.byte("A"), string.byte("z"))
		if isInArray({91,92,93,94,95,96}, n) or isInArray(key, string.char(n)) then
			repeat
				n = math.random(string.byte("A"), string.byte("z"))
			until not isInArray({91,92,93,94,95,96}, n) and not isInArray(key, string.char(n))
		end
		table.insert(key, string.char(n))
	until #key == 9
	return key
end

function saveEncryptionKey()
	local key = generateEncryptionKey()
	db.query("CREATE TABLE IF NOT EXISTS `recovery_key` (`id` tinyint(1) NOT NULL,`key1` varchar(1) NOT NULL,`key2` varchar(1) NOT NULL,`key3` varchar(1) NOT NULL,`key4` varchar(1) NOT NULL,`key5` varchar(1) NOT NULL,`key6` varchar(1) NOT NULL,`key7` varchar(1) NOT NULL,`key8` varchar(1) NOT NULL,`key9` varchar(1) NOT NULL,UNIQUE KEY (`id`)) ENGINE=InnoDB;")
	local res = db.storeQuery("SELECT * FROM `recovery_key` WHERE `id` = 1")
	if not res then
		db.query("INSERT INTO `recovery_key`(`id`, `key1`, `key2`, `key3`, `key4`, `key5`, `key6`, `key7`, `key8`, `key9`) VALUES (1,'".. key[1] .."','".. key[2] .."','".. key[3] .."','".. key[4] .."','".. key[5] .."','".. key[6] .."','".. key[7] .."','".. key[8] .."','".. key[9] .."')")
	end
	result.free(res)
end

function loadEncryptionKey()
	local res = db.storeQuery("SELECT `key1`, `key2`, `key3`, `key4`, `key5`, `key6`, `key7`, `key8`, `key9` FROM `recovery_key` WHERE `id` = 1")
	local keys = {"key1","key2","key3","key4","key5","key6","key7","key8","key9"}
	local encrypt = {}
	if res then
		for k, v in pairs(keys) do
			table.insert(encrypt, result.getDataString(res, v))
		end
	end
	result.free()
	return encrypt
end

function kickPlayer(cid)
	local player = Player(cid)
	if player then
		player:remove()
	end
end

function AccountManager.createRecoveryKey(self)
	local key = ""
	local seq1 = math.random(3,9)
	math.randomseed(os.time()*os.time())
	local seq2 = math.random(3,9)
	key = tostring(math.floor((seq1 ^ seq2)))
	key = key .."".. encryptionKey[seq1] .."".. encryptionKey[seq2]
	repeat
		local rnd = math.random(0,9)
		key = key .."".. tostring(rnd)
	until string.len(key) >= 15
	return self.mask.recKey == key
end

function AccountManager.isValidRecoveryKeySequence(self)		
	local gKey = ""
	local t = {}; local p = {}; q = ""
	if string.find(self.mask.recKey, "%a") then
		local a = string.find(self.mask.recKey, "%a")
		local z = ""
		for i = 1, a-1 do
			local c = self.mask.recKey:sub(i,i)
			q = q .."".. c
		end
		for i = a, a+1 do
			local c = self.mask.recKey:sub(i,i)
			table.insert(t, c)
		end
		if not isInArray(self.encryptionKey, t[1]) or not isInArray(self.encryptionKey, t[2]) then
			return false
		end
		for y, x in pairs(t) do
			for k, v in pairs(self.encryptionKey) do
				if x == v then
					table.insert(p, k)
				end
			end
		end
		gKey = math.floor((p[1] ^ p[2])) .."".. t[1] .."".. t[2]
		if string.find(self.mask.recKey, gKey) then
			return true
		end
	end
	return false
end

function AccountManager.createAccountMask(self)
	self.mask = {}
		self.mask.accName = ""
		self.mask.accPassword = ""
		self.mask.accPinCode = -1
		self.mask.accEmail = ""
		self.mask.recKey = ""
		self.mask.charName = ""
		self.mask.charVoc = -1
		self.mask.charLevel = -1
		self.mask.charGender = -1
end

function AccountManager.createRecoverAccountMask(self)
	self.mask = {}
		self.mask.accName = ""
		self.mask.email = ""
		self.mask.accPassword = ""
		self.mask.recKey = ""
end

function AccountManager.createCharacterMask(self)
	self.mask = {}
		self.mask.charName = ""
		self.mask.charVoc = -1
		self.mask.charLevel = -1
		self.mask.charGender = -1
end

function AccountManager.createChangePasswordMask(self)
	self.mask = {}
		self.mask.accId = -1
		self.mask.accPinCode = ""
		self.mask.newPassword = ""
end

function AccountManager.createChangeEmailMask(self)
	self.mask = {}
		self.mask.accId = -1
		self.mask.accPinCode = ""
		self.mask.newEmail = ""
end

function AccountManager.clearMask(self)
	self.mask = nil
	self.state = 0
end

function AccountManager.verifyAccountMask(self)
	local ret = true
	for k, v in pairs(self.mask) do
		if type(v) == "string" then
			if v == "" then
				ret = false
			end
		elseif type(v) == "number" then
			if v == -1 then
				ret = false
			end
		end
	end
	if isInArray(self.existingAccountNames, self.mask.accName) then
		ret = false
	elseif isInArray(self.existingCharacterNames, self.mask.charName) then
		ret = false
	end
	return ret
end

function AccountManager.verifyRecoverAccountMask(self)
	local ret = true
	if not isInArray(self.existingAccountNames, self.mask.accName) then
		return false
	end
	for k, v in pairs(self.mask) do
		if v == "" then
			ret = false
		end
	end
	return ret
end

function AccountManager.verifyCharacterMask(self)
	local ret = true
	for k, v in pairs(self.mask) do
		if type(v) == "string" then
			if v == "" then
				ret = false
			end
		elseif type(v) == "number" then
			if v == -1 then
				ret = false
			end
		end
	end
	if isInArray(self.existingCharacterNames, self.mask.charName) then
		ret = false
	end
	return ret
end

function AccountManager.verifyChangePasswordMask(self)
	local ret = true
	for k, v in pairs(self.mask) do
		if type(v) == "string" then
			if v == "" then
				ret = false
			end
		elseif type(v) == "number" then
			if v == -1 then
				ret = false
			end
		end
	end
	return ret
end

function AccountManager.verifyChangeEmailMask(self)
	local ret = true
	for k, v in pairs(self.mask) do
		if type(v) == "string" then
			if v == "" then
				ret = false
			end
		elseif type(v) == "number" then
			if v == -1 then
				ret = false
			end
		end
	end
	return ret
end

function AccountManager.createAccount(self, player)
	if not self:verifyAccountMask() then
		player:sendTextToClient("There has been an error in verifying the Account details, Account creating has been terminated, you will be logged out in 5 seconds", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		addEvent(kickPlayer, 1000*5, player:getId())
		self:clearMask()
		return false
	end
	db.query("INSERT INTO `accounts`(`name`, `password`, `type`, `premdays`, `lastday`, `email`, `creation`, `recovery_key`, `pin_code`) VALUES ('".. self.mask.accName .."', '".. self.mask.accPassword .."', 0, 0, 0, '".. self.mask.email .."', ".. os.time() ..", '".. self.mask.recKey .."', '".. self.mask.pinCode .."')")
	table.insert(self.existingAccountNames, self.mask.accName)
	local pid = db.storeQuery("SELECT `id` FROM `accounts` WHERE `name` = '".. self.mask.accName .."'")
	local res = 0
	local exp = level == 1 and 0 or 4200
	local lookType = gender == 0 and 136 or 128
	if pid then
		res = result.getDataInt(pid, "id")
		local player = db.query("INSERT INTO `players`(`name`, `group_id`, `account_id`, `level`, `vocation`, `health`, `healthmax`, `experience`, `lookbody`, `lookfeet`, `lookhead`, `looklegs`, `looktype`, `lookaddons`, `maglevel`, `mana`, `manamax`, `manaspent`, `soul`, `town_id`, `posx`, `posy`, `posz`, `conditions`, `cap`, `sex`, `lastlogin`, `lastip`, `save`, `skull`, `skulltime`, `lastlogout`, `blessings`, `onlinetime`, `deletion`, `balance`, `offlinetraining_time`, `offlinetraining_skill`, `stamina`, `skill_fist`, `skill_fist_tries`, `skill_club`, `skill_club_tries`, `skill_sword`, `skill_sword_tries`, `skill_axe`, `skill_axe_tries`, `skill_dist`, `skill_dist_tries`, `skill_shielding`, `skill_shielding_tries`, `skill_fishing`, `skill_fishing_tries`) VALUES ('".. self.mask.charName .."',1,".. res ..",".. self.mask.level ..",".. self.mask.charVoc ..",185,185,".. exp ..",68,76,78,58,".. lookType.. ",0,0,40,40,0,100,".. accountManagerConfig.townID ..",".. accountManagerConfig.startDest.x ..",".. accountManagerConfig.startDest.y ..",".. accountManagerConfig.startDest.z ..",0,435,".. self.mask.gender ..",0,0,1,0,0,0,0,0,0,0,43200,-1,2520,10,0,10,0,10,0,10,0,10,0,10,0,10,0)")
		table.insert(self.existingCharacterNames, self.mask.charName)
	end
	result.free(pid)
	return true
end

function AccountManager.createCharacter(self, player)
	if not self:verifyCharacterMask() then
		player:sendTextToClient("There has been an error in verifying the Character details, Character creating has been terminated", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		self:clearMask()
		return false
	end
	local pid = db.storeQuery("SELECT `account_id` FROM `players` WHERE `name` = '".. player:getName() .."'")
	local res = 0
	local exp = level == 1 and 0 or 4200
	local lookType = gender == 0 and 136 or 128
	if pid then
		res = result.getDataInt(pid, "account_id")
		db.query("INSERT INTO `players`(`name`, `group_id`, `account_id`, `level`, `vocation`, `health`, `healthmax`, `experience`, `lookbody`, `lookfeet`, `lookhead`, `looklegs`, `looktype`, `lookaddons`, `maglevel`, `mana`, `manamax`, `manaspent`, `soul`, `town_id`, `posx`, `posy`, `posz`, `conditions`, `cap`, `sex`, `lastlogin`, `lastip`, `save`, `skull`, `skulltime`, `lastlogout`, `blessings`, `onlinetime`, `deletion`, `balance`, `offlinetraining_time`, `offlinetraining_skill`, `stamina`, `skill_fist`, `skill_fist_tries`, `skill_club`, `skill_club_tries`, `skill_sword`, `skill_sword_tries`, `skill_axe`, `skill_axe_tries`, `skill_dist`, `skill_dist_tries`, `skill_shielding`, `skill_shielding_tries`, `skill_fishing`, `skill_fishing_tries`) VALUES ('".. self.mask.charName .."',1,".. res ..",".. self.mask.level ..",".. self.mask.charVoc ..",185,185,".. exp ..",68,76,78,58,".. lookType.. ",0,0,40,40,0,100,".. accountManagerConfig.townID ..",".. accountManagerConfig.startDest.x ..",".. accountManagerConfig.startDest.y ..",".. accountManagerConfig.startDest.z ..",0,435,".. self.mask.gender ..",0,0,1,0,0,0,0,0,0,0,43200,-1,2520,10,0,10,0,10,0,10,0,10,0,10,0,10,0)")
		table.insert(self.existingCharacterNames, self.mask.charName)
	end
	result.free(pid)
	return true
end

function AccountManager.changePassword(self, player)
	if not self:verifyChangePasswordMask() then
		player:sendTextToClient("There has been an error in verifying the change Password details, change Password has been terminated", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		self:clearMask()
		return false
	end
	local res = db.query("UPDATE `accounts` SET `password` = '".. self.mask.newPassword .."' WHERE `id` = ".. self.mask.accId .."")
	return res and true or false
end

function AccountManager.changeAccountPassword(self, player)
	if not self:verifyRecoverAccountMask() then
		player:sendTextToClient("There has been an error in verifying the Recover Account details, Recover Account has been terminated, you will be logged out in 5 seconds", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		addEvent(kickPlayer, 1000*5, player:getId())
		self:clearMask()
		return false
	end
	db.query("UPDATE `accounts` SET `password` = '".. self.mask.accPassword .."' WHERE `name` = '".. self.mask.accName .."'")
	return true
end

function AccountManager.changeEmail(self, player)
	if not self:verifyChangeEmailMask() then
		player:sendTextToClient("There has been an error in verifying the change Email details, change Email has been terminated", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		self:clearMask()
		return false
	end
	local res = db.query("UPDATE `accounts` SET `email` = '".. self.mask.newEmail .."' WHERE `id` = ".. self.mask.accId .."")
	return res and true or false
end

function string:findDoubleSpace()
    local t = {}
    local i = 0
    while true do
		i = string.find(self, " ", i+1)
		if i == nil then break end
		table.insert(t, i)
    end
    local ret = false
    local f = {}
    local j = 0
    for k, v in ipairs(t) do
        if k == 1 then
            j = v
        end
        if k > 1 and k <= #t then
            if (j+1) == v then
                table.insert(f, {j,v})
                ret = true
            end
            j = v
        end
    end
    return ret and f or ret
end

function AccountManager.validateCharacterName(self, player, message)
	player:sendTextToClient('> "'.. message ..'"', "Account Manager", 9, TALKTYPE_CHANNEL_O)
	if string.find(message, ("[%a%s]")) and not message:findDoubleSpace() and not message:find(" ", message:len()) then
		for i = 1,#accountManagerConfig.blockedNames do
			if string.find(message, accountManagerConfig.blockedNames[i]) then
				player:sendTextToClient("This Character Name consists of illegal parts (ex: GOD / GM / CM), choose another please.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
				return
			end
		end
		if string.len(message) >= 3 and string.len(message) <= 15 then
			if not isInArray(self.existingCharacterNames, message) then
				self.mask.charName = message
				player:sendTextToClient("Character Name accepted, please choose your Gender.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
				player:sendTextToClient("Gender: male or female", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
				self.state = self.state + 1
			else
				player:sendTextToClient("This Character Name already exists, please choose another.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
			end
		else
			player:sendTextToClient("This Character Name is either to short or to long (min = 3, max = 15)", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		end
	else
		player:sendTextToClient("This Character Name consists of illegal characters, only letters and single type spaces are accepted, choose another please.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
	end
end

function AccountManager.validateAccountName(self, player, message)
	player:sendTextToClient('> "'.. message ..'"', "Account Manager", 9, TALKTYPE_CHANNEL_O)
	if message:match("%w") then
		if string.len(message) >= 5 and string.len(message) <= 15 then
			if not isInArray(self.existingAccountNames, message) then
				self.mask.accName = message
				player:sendTextToClient("Account Name accepted, please choose your Password.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
				self.state = self.state + 1
			else
				player:sendTextToClient("This Account Name already exists, please choose another.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
			end
		else
			player:sendTextToClient("This Account Name is either to short or to long (min = 5, max = 15)", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		end
	else
		player:sendTextToClient("Account Name consists of illegal characters, only alphanumeric Account Names are accepted, choose another please.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
	end
end

function AccountManager.validateAccountPassword(self, player, message)
	player:sendTextToClient('> "'.. message ..'"', "Account Manager", 9, TALKTYPE_CHANNEL_O)
	if message:match("%w") then
		if string.len(message) >= 5 and string.len(message) <= 15 then
			self.mask.accPassword = transformToSha1(message)
			player:sendTextToClient("Account Password accepted, please tell me your Account Pin Code.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
			player:sendTextToClient("NOTE: Pin Code is a 4 digit code, which needs to be entered upon password change / email change / character creation & deletion", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
			self.state = self.state + 1
		else
			player:sendTextToClient("This Account Password is either to short or to long (min = 5, max = 15)", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		end
	else
		player:sendTextToClient("Account Password consists of illegal characters, only alphanumeric Account Passwords are accepted, choose another please.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
	end
end

function AccountManager.validateAccountPinCode(self, player, message)
	player:sendTextToClient('> "'.. message ..'"', "Account Manager", 9, TALKTYPE_CHANNEL_O)
	if message:match("%d") then
		if message:len() == 4 then
			self.mask.accPinCode = transformToSha1(message)
			player:sendTextToClient("Account Pin Code accepted, please tell me your email.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
			self.state = self.state + 1
		else
			player:sendTextToClient("This Account Pin Code is either to short or to long (exactly 4 digits)", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		end
	else
		player:sendTextToClient("Account Pin Code consists of illegal characters, only digits are accepted, choose another please.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
	end
end

function AccountManager.validateAccountEmail(self, player, message)
	player:sendTextToClient('> "'.. message ..'"', "Account Manager", 9, TALKTYPE_CHANNEL_O)
	if message:match("[%w@._-]") and string.find(message, "[@.]") then
		if string.len(message) >= 7 and string.len(message) <= 25 then
			self.mask.accEmail = message
			player:sendTextToClient("Account email accepted, please choose your Character Name.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
			self.state = self.state + 1
		else
			player:sendTextToClient("This email is either to short or to long (min = 7, max = 25)", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		end
	else
		player:sendTextToClient("Account email consists of illegal characters, only alphanumeric & [@ . - _] are accepted ex(test@test.net), choose another please.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
	end
end

function AccountManager.validateCharacterGender(self, player, message)
	player:sendTextToClient('> "'.. message ..'"', "Account Manager", 9, TALKTYPE_CHANNEL_O)
	for k, v in pairs(accountManagerConfig.gender) do
		if v == message:lower() then
			self.mask.charGender = k
		end
	end
	if self.mask.charGender == "" then
		player:sendTextToClient("This Gender does not exist, please choose another.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		return false
	end
	if accountManagerConfig.canchooseVoc then
		player:sendTextToClient("A ".. message .." it is, please choose your Vocation.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		local str = accountManagerConfig.voc[1]
		local begin = true
		for i = 2, #accountManagerConfig.voc do
			str = str.." | ".. accountManagerConfig.voc[i]
		end
		player:sendTextToClient("Vocations: ".. str, "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		self.state = self.state + 1
	else
		self.mask.charLevel = 1
		self.mask.charVoc = 0
		if self.create == "account" then
			self:createRecoveryKey()
			if self:createAccount(player) then
				player:sendTextToClient("Account and Character have successfully been created.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
				player:sendTextToClient("IMPORTANT! write down your Recovery Key, you need it in order to retrieve an Account where you lost your Password.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
				player:sendTextToClient('> "'.. self.mask.recKey ..'"', "Account Manager", 9, TALKTYPE_CHANNEL_O)
				player:sendTextToClient("Your Account has been created, you can login now.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
				self:clearMask()
			end
		else
			if self:createCharacter(player) then
				player:sendTextToClient("Character has successfully been created.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
				self:clearMask()
			end
		end
	end
end

function AccountManager.validateCharacterVocation(self, player, message)
	player:sendTextToClient('> "'.. message ..'"', "Account Manager", 9, TALKTYPE_CHANNEL_O)
	for k, v in pairs(accountManagerConfig.voc) do
		if v == message:lower() then
			self.mask.charVoc = k
			self.mask.charLevel = 8
		end
	end
	if self.mask.charVoc == "" then
		player:sendTextToClient("This Vocation does not exist, please choose another.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		return false
	end
	if self.create == "account" then
		self:createRecoveryKey()
		if self:createAccount(player) then
			player:sendTextToClient("Account and Character have successfully been created.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
			player:sendTextToClient("IMPORTANT! write down your Recovery Key, you need it in order to retrieve an Account where you lost your Password.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
			player:sendTextToClient('> "'.. self.mask.recKey ..'"', "Account Manager", 9, TALKTYPE_CHANNEL_O)
			player:sendTextToClient("Your Account has been created, you can login now.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
			self:clearMask()
		end
	else
		if self:createCharacter(player) then
			player:sendTextToClient("Character has successfully been created.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
			self:clearMask()
		end
	end
end

function AccountManager.validateRecoverAccountName(self, player, message)
	player:sendTextToClient('> "'.. message ..'"', "Account Manager", 9, TALKTYPE_CHANNEL_O)
	if isInArray(self.existingAccountNames, message) then
		self.mask.accName = message
		player:sendTextToClient("Account Name verified, please tell me the Recovery Key.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		self.state = self.state + 1
	else
		-- kicking the player to avoid looping account names to fish them out.
		player:sendTextToClient("This Account Name does not exist, you will be logged out in 5 seconds.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		self:clearMask()
		addEvent(kickPlayer, 1000*5, player:getId())
	end
end

function AccountManager.validateRecoveryKey(self, player, message)
	player:sendTextToClient('> "'.. message ..'"', "Account Manager", 9, TALKTYPE_CHANNEL_O)
	self.mask.recKey = message
	if self:isValidRecoveryKeySequence() then
		local res = db.storeQuery("SELECT `email`, `recovery_key` FROM `accounts` WHERE `name` = '".. self.mask.accName .."'")
		if res then
			self.mask.email = result.getDataString(res, "email")
			self.mask.recKey = result.getDataString(res, "recovery_key")
		end
		result.free(res)
		if string.find(message, self.mask.recKey) then
			player:sendTextToClient("Account Recovery Key verified, please tell me the email.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
			self.state = self.state + 1
		else
			-- kicking the player to avoid looping account emails to fish them out.
			player:sendTextToClient("The Recovery Key does not match with the Account Name, you will be logged out in 5 seconds.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
			self:clearMask()
			addEvent(kickPlayer, 1000*5, player:getId())
		end
	else
		-- kicking the player to avoid looping account emails to fish them out.
		player:sendTextToClient("This key is not valid, you will be logged out in 5 seconds.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		self:clearMask()
		addEvent(kickPlayer, 1000*5, player:getId())
	end
end

function AccountManager.validateRecoveryEmail(self, player, message)
	player:sendTextToClient('> "'.. message ..'"', "Account Manager", 9, TALKTYPE_CHANNEL_O)
	if string.find(message, self.mask.email) then
		player:sendTextToClient("Account Email verified, please tell me the new password for the Account.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		self.state = self.state + 1
	else
		-- kicking the player to avoid looping account emails to fish them out.
		player:sendTextToClient("The email does not match with the Account Name, you will be logged out in 5 seconds.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		self:clearMask()
		addEvent(kickPlayer, 1000*5, player:getId())
	end
end

function AccountManager.validateRecoveryChangePassword(self, player)
	player:sendTextToClient('> "'.. message ..'"', "Account Manager", 9, TALKTYPE_CHANNEL_O)
	if message:match("%w") then
		if string.len(message) >= 5 and string.len(message) <= 15 then
			self.mask.accPassword = transformToSha1(message)
			if self:changeAccountPassword(player) then
				player:sendTextToClient("Account Password has been changed.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
			end
			self:clearMask()
		else
			player:sendTextToClient("This Account Password is either to short or to long (min = 5, max = 15)", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		end
	else
		player:sendTextToClient("Account Password consists of illegal characters, only alphanumeric Account Passwords are accepted, choose another please.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
	end
end

function AccountManager.validateCheckAccountPinCode(player, message)
	player:sendTextToClient('> "'.. message ..'"', "Account Manager", 9, TALKTYPE_CHANNEL_O)
	if message:match("%d") then
		if message:len() == 4 then
			-- we don't want to execute the query a few times if we fetched it already and the player tries a second time.
			if self.mask.accId == -1 then
				local res = db.storeQuery("SELECT `account_id` FROM `players` WHERE `name` = '".. player:getName() .."'")
				if res then
					self.mask.accId = result.getDataInt(res, "account_id")
				end
				result.free(res)
				local res = db.storeQuery("SELECT `pin_code` FROM `accounts` WHERE `id` = ".. self.mask.accId .."")
				if res then
					self.mask.accPinCode = result.getDataString(res, "pin_code")
				end
				result.free(res)
			end
			if self.mask.accPinCode == transformToSha1(message) then
				if self.create == "password" then
					self.state = self.state + 1
					player:sendTextToClient("Account Pin Code has been verified, please tell me your new Password.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
				else
					self.state = self.state + 1
					player:sendTextToClient("Account Pin Code has been verified, please tell me your new Email.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
				end
			else
				player:sendTextToClient("Account Pin Code does not match, please try again.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
			end
		else
			player:sendTextToClient("This Account Pin Code is either to short or to long (exactly 4 digits)", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		end
	else
		player:sendTextToClient("Account Pin Code is malformed.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
	end
end

function AccountManager.validateChangeAccountPassword(self, player, message)
	player:sendTextToClient('> "'.. message ..'"', "Account Manager", 9, TALKTYPE_CHANNEL_O)
	if message:match("%w") then
		if string.len(message) >= 5 and string.len(message) <= 15 then
			self.mask.newPassword = transformToSha1(message)
			if self:changePassword(player) then
				player:sendTextToClient("Password has successfully been changed.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
				self:clearMask()
			end
		else
			player:sendTextToClient("This Account Password is either to short or to long (min = 5, max = 15)", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		end
	else
		player:sendTextToClient("Account Password consists of illegal characters, only alphanumeric Account Passwords are accepted, choose another please.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
	end
end

function AccountManager.validateChangeAccountEmail(self, player)
	player:sendTextToClient('> "'.. message ..'"', "Account Manager", 9, TALKTYPE_CHANNEL_O)
	if message:match("[%w@._-]") and string.find(message, "[@.]") then
		if message:len() >= 7 and message:len() <= 25 then
			self.mask.newEmail = message
			if self:changeEmail(player) then
				player:sendTextToClient("Account email has successfully been changed.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
				self:clearMask()
			end
		else
			player:sendTextToClient("This email is either to short or to long (min = 7, max = 25)", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
		end
	else
		player:sendTextToClient("Account email consists of illegal characters, only alphanumeric & [@ . - _] are accepted ex(test@test.net), choose another please.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
	end
end

function handleAccountManagerLogin(player)
    if player:getName() == "Account Manager" then
        if accountManagerConfig.kickWithSameIP then
            local players = Game.getPlayers()
            local t = {}
            for k,v in pairs(players) do
                if v:getName() == "Account Manager" then
                    if v:getIp() == player:getIp() then
                        table.insert(t, v:getId())
                    end
                end
            end
            if #t > accountManagerConfig.kickAtAmmount then
                player:disconnectWithReason("There are to much Account Managers online with this IP")
                return false
            end
        end
        if not accountManagerConfig.enabled then
            player:disconnectWithReason("Account Manager is disabled")
            return false
        end
        local str = "\n-----------------------------------\n"
        str = str .."-->             Account Manager ALPHA                 <--\n"
        str = str .."-->       Author: Evil Hero @ otland.net            <--\n"
        str = str .."-----------------------------------"
        player:sendTextToLocalChat(MESSAGE_STATUS_CONSOLE_BLUE, str)
        player:sendTextToLocalChat(MESSAGE_STATUS_CONSOLE_BLUE, "You need to talk in the 'Account Manager' chat channel")
        player:openChannel(9)
        player:sendTextToClient("write 'info' if you need help.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
    end
    return true
end

function handleAccountManagerStartup()
    if accountManagerConfig.enabled then
        -- Fetch all already existing Account Names from the database for the Account Manager
        local resultId = db.storeQuery("SELECT `name` FROM `accounts`")
        if resultId then
            repeat
                local name = result.getDataString(resultId, "name")
                table.insert(AccountManager.existingAccountNames, name)
            until not result.next(resultId)
            result.free(resultId)
        end
    
        -- Fetch all already existing Character Names from the database for the Account Manager
        local resultId = db.storeQuery("SELECT `name` FROM `players`")
        if resultId then
            repeat
                local name = result.getDataString(resultId, "name")
                table.insert(AccountManager.existingCharacterNames, name)
            until not result.next(resultId)
            result.free(resultId)
        end
        math.randomseed(os.mtime())
        saveEncryptionKey()
        AccountManager.encryptionKey = loadEncryptionKey()
    end
end

function handleAccountManagerParsePacket(player, packet)
	if accountManagerConfig.enabled then
		if player:getName() == "Account Manager" then
			local p = {0xCB,0xA2,100,101,102,103,104,0xE6,0xE8,0x78,0xD4,0x7D,0x82,0x7F,0x83,0x84,0x85,0x9A,0xA1,0xA3,0xA4,0xAA,0xAB,0xD2,0xD3,0xDC,0xF0,0xF1,0xF5,0xF6,0xF9}
			if isInArray(p, packet) then
				return false
			end
		end
	end
	return true
end

function handleAccountManagerMove(player, creature)
	if accountManagerConfig.enabled then
		if player:getName() == "Account Manager" or creature:getName() == "Account Manager" then
			return false
		end
	end
	return true
end

function handleAccountManagerTradeRequest(player, creature)
	if accountManagerConfig.enabled then
		if player:getName() == "Account Manager" or creature:getName() == "Account Manager" then
			return false
		end
	end
	return true
end