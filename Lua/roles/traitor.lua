local role = Traitormod.RoleManager.Roles.Role:new()
role.Name = "Traitor"
role.Antagonist = true

function role:CompletedObjectives(name)
    local num = 0
    for key, value in pairs(self.Objectives) do
        if value.Name == name then
            num = num + 1
        end
    end
    return num
end

function role:AssasinationLoop(first)
    local this = self
    
    local assassinate = Traitormod.RoleManager.Objectives.Assassinate:new()
    assassinate:Init(self.Character)
    local target = self:FindValidTarget(assassinate)
    if assassinate:Start(target) then
        self:AssignObjective(assassinate)

        local num = self:CompletedObjectives()
        assassinate.AmountPoints = assassinate.AmountPoints + (num * self.PointsPerAssassination)

        local client = Traitormod.FindClientCharacter(self.Character)

        assassinate.OnAwarded = function ()
            if client then
                Traitormod.SendMessage(client, Traitormod.Language.AssassinationNextTarget, "")
            end

            Traitormod.SendMessageCharacter(assassinate.Target, Traitormod.Language.KilledByTraitor, "InfoFrameTabButton.Traitor")

            local delay = math.random(this.NextAssassinateDelayMin, this.NextAssassinateDelayMax) * 1000
            Timer.Wait(function (...)
                this:AssasinationLoop()
            end, delay)
        end


        if client and not first then
            Traitormod.SendMessage(client, string.format(Traitormod.Language.AssassinationNewObjective, target.Name), "GameModeIcon.pvp")
            Traitormod.UpdateVanillaTraitor(client, true, self:Greet())  
        end
    else
        Timer.Wait(function ()
            this:AssasinationLoop()
        end, 5000)
    end
end

function role:Start()
    self:AssasinationLoop(true)

    local pool = {}
    for key, value in pairs(self.SubObjectives) do pool[key] = value end

    local toRemove = {}
    for key, value in pairs(pool) do
        local objective = Traitormod.RoleManager.FindObjective(value)
        if objective ~= nil then
            objective = objective:new()
            objective:Init(self.Character)
            if objective.AlwaysActive and objective:Start(self.Character) then
                self:AssignObjective(objective)
                table.insert(toRemove, key)
            end
        end
    end
    for key, value in pairs(toRemove) do table.remove(pool, value) end

    for i = 1, 3, 1 do
        local objective = Traitormod.RoleManager.RandomObjective(pool)
        if objective == nil then break end

        objective = objective:new()
        objective:Init(self.Character)
        local target = self:FindValidTarget(objective)

        if objective:Start(target) then
            self:AssignObjective(objective)
            for key, value in pairs(pool) do
                if value == objective.Name then
                    table.remove(pool, key)
                end
            end
        end
    end

    local text = self:Greet()
    local client = Traitormod.FindClientCharacter(self.Character)
    if client then
        Traitormod.SendTraitorMessageBox(client, text)
        Traitormod.UpdateVanillaTraitor(client, true, text)
    end
end

---@return string mainPart, string subPart
function role:ObjectivesToString()
    local primary = Traitormod.StringBuilder:new()
    local secondary = Traitormod.StringBuilder:new()

    for _, objective in pairs(self.Objectives) do
        -- Assassinate objectives are primary
        local buf = objective.Name == "Assassinate" and primary or secondary

        if objective:IsCompleted() then
            buf:append(" > ", objective.Text, Traitormod.Language.Completed)
        else
            buf:append(" > ", objective.Text, string.format(Traitormod.Language.Points, objective.AmountPoints))
        end
    end
    if #primary == 0 then
        primary(" > No objectives yet... Stay furtile.")
    end

    return primary:concat("\n"), secondary:concat("\n")
end

function role:Greet()
    local partners = Traitormod.StringBuilder:new()
    local traitors = Traitormod.RoleManager.FindCharactersByRole("Traitor")
    for _, character in pairs(traitors) do
        if character ~= self.Character then
            partners('"%s"\n', character.Name)
        end
    end
    partners = partners:concat(" ")
    local primary, secondary = self:ObjectivesToString()

    local sb = Traitormod.StringBuilder:new()
    sb("You are a traitor!\n\n")
    sb("Your main objectives are:\n")
    sb(primary)
    sb("\n\nYour secondary objectives are:\n")
    sb(secondary)
    sb("\n\n")
    if #traitors < 2 then
        sb("You are the only traitor.")
    else
        sb("Partners: ")
        sb(partners)
    end
    return sb:concat()
end

function role:OtherGreet()
    local sb = Traitormod.StringBuilder:new()
    local primary, secondary = self:ObjectivesToString()
    sb("Traitor %s.", self.Character.Name)
    sb("\nTheir main objectives were:\n")
    sb(primary)
    sb("\nTheir secondary objectives were:\n")
    sb(secondary)
    return sb:concat()
end

function role:FilterTarget(objective, character)
    if not self.SelectBotsAsTargets and character.IsBot then return false end

    if objective.Name == "Assassinate" and self.SelectUniqueTargets then
        for key, value in pairs(Traitormod.RoleManager.FindCharactersByRole("Traitor")) do
            local role = Traitormod.RoleManager.GetRoleByCharacter(value)

            for key, obj in pairs(role.Objectives) do
                if obj.Name == "Assassinate" and obj.Target == character then
                    return false
                end
            end
        end
    end

    if character.TeamID ~= CharacterTeamType.Team1 and not self.SelectPiratesAsTargets then
        return false
    end

    return Traitormod.RoleManager.Roles.Role.FilterTarget(self, objective, character)
end

return role