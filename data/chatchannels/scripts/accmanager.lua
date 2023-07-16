handler = {}
handler.yes = {}
handler.no = {__index = handler.no}
setmetatable(handler.no, {
    __index = handler.no,
    __call = 
    function(self, player, manager)
        self[manager.state](player)
        manager.state = 0
        manager:clearMask()
    end
})
    
function handler.info(player)
    player:sendTextToClient("Hello I'm your Account Manager, what kind of action would you like to perform?", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
    if player:getName() == "Account Manager" then
        player:popupFYI("create = create Account\nrecover = recover lost Account")
    else
        player:popupFYI("character = create Character\nemail = change E-mail\npassword = change Password\ndelete = delete Character")
    end
end
 
function handler.create(player, manager)
    if manager.state == 0 and player:getName() == "Account Manager" then
        manager.state = 1
        manager.create = "account"
        manager:createAccountMask()
        player:sendTextToClient("You would like to create an account?", "Account Manager", 9, TALKTYPE_CHANNEL_R1)      
    end
end
 
handler.recover = function(player, manager)
    if manager.state == 0 and player:getName() == "Account Manager" then
        manager.state = 10
        manager.create = "recover"
        manager:createRecoverAccountMask()
        player:sendTextToClient("You would like to recover an Account?", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
    end
end
    
handler.character = function(player, manager)
    if manager.state == 0 and player:getName() ~= "AccountManager" then
        if player:checkCharacterListSize() < accountManagerConfig.maxCharacters then
            manager.state = 15
            manager.create = "character"
            manager:createCharacterMask()
            player:sendTextToClient("You would like to create a Character?", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
        else
            player:sendTextToClient("You have the max ammount of allowed Characters!", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
        end
    end
end
    
handler.password = function(player, manager)
    if manager.state == 0 and player:getName() ~= "Account Manager" then
        manager.state = 16
        manager.create = "password"
        manager:createChangePasswordMask()
        player:sendTextToClient("You would like to change your Password?", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
    end
end
 
handler.email = function(player, manager)
    if manager.state == 0 and player:getName() ~= "Account Manager" then
        manager.state = 19
        manager.create = "email"
        manager:createChangeEmailMask()
        player:sendTextToClient("You would like to change your Email?", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
    end
end
    
handler[2] = function(player, manager, message) manager:validateAccountName(player, message) end
handler[3] = function(player, manager, message) manager:validateAccountPassword(player, message) end
handler[4] = function(player, manager, message) manager:validateAccountPinCode(player, message) end
handler[5] = function(player, manager, message) manager:validateAccountEmail(player, message) end
handler[6] = function(player, manager, message) manager:validateCharacterName(player, message) end
handler[7] = function(player, manager, message) manager:validateCharacterGender(player, message) end
handler[8] = function(player, manager, message) manager:validateCharacterVocation(player, message) end
handler[11] = function(player, manager, message) manager:validateRecoveryAccountName(player, message) end
handler[12] = function(player, manager, message) manager:validateRecoveryKey(player, message) end
handler[13] = function(player, manager, message) manager:validateRecoveryEmail(player, message) end
handler[14] = function(player, manager, message) manager:validateRecoveryChangePassword(player, message) end
handler[17] = function(player, manager, message) manager:validateCheckAccountPinCode(player, message) end
handler[18] = function(player, manager, message) manager:validateChangeAccountPassword(player, message) end
handler[20] = function(player, manager, message) manager:validateCheckAccountPinCode(player, message) end
handler[21] = function(player, manager, message) manager:validateChangeAccountEmail(player, message) end
 
handler.yes[1] = function(player, manager)
    manager.state = 2
    player:sendTextToClient("What would you like to have as your Account Name?", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
end
handler.yes[10] = function(player, manager)
    manager.state = 11
    player:sendTextToClient("Please tell me the Account Name of it.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
end
handler.yes[15] = function(player, manager)
    manager.state = 5
    player:sendTextToClient("Please tell me the Character Name.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
end
handler.yes[16] = function(player, manager)
    manager.state = 17
    player:sendTextToClient("Please tell me your Pin Code.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
end
handler.yes[19] = function(player, manager)
    manager.state = 20
    player:sendTextToClient("Please tell me your Pin Code.", "Account Manager", 9, TALKTYPE_CHANNEL_R1)
end 
    
handler.no[1] = function(player) player:sendTextToClient("Account creation terminated.", "Account Manager", 9, TALKTYPE_CHANNEL_R1) end
handler.no[10] = function(player) player:sendTextToClient("Recover Account terminated.", "Account Manager", 9, TALKTYPE_CHANNEL_R1) end
handler.no[15] = function(player) player:sendTextToClient("Character creation terminated.", "Account Manager", 9, TALKTYPE_CHANNEL_R1) end
handler.no[16] = function(player) player:sendTextToClient("Change Password terminated.", "Account Manager", 9, TALKTYPE_CHANNEL_R1) end
handler.no[19] = function(player) player:sendTextToClient("Change Email terminated.", "Account Manager", 9, TALKTYPE_CHANNEL_R1) end    
 
function onSpeak(player, type, message)
    if not accountManagerConfig.enabled then
        return false
    end
    
    local manager = AccountManager(player:getId())
    
    if message == "yes" and manager.state > 0 then
        handler.yes[manager.state](player, manager)
        return false
    end
    if message == "no" and manager.state > 0 then
        handler.no(player, manager)
        return false
    end
    if not handler[message](player, manager, message) or not handler[manager.state](player, manager, message) then
        return false
    end
    
    return false
end