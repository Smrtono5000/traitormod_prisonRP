local extension = {}

extension.Identifier = "pressuremidjoin"

extension.Init = function ()
    Hook.Add("character.created", "Traitormod.GivePressureResistance", function(character)
        if not character.IsHuman then return end
        local pressurePrefab = AfflictionPrefab.Prefabs["pressurestabilized"].Instantiate(30)
        local limb = character.AnimController.MainLimb
        character.CharacterHealth.ApplyAffliction(limb, pressurePrefab)
        Networking.CreateEntityEvent(character, Character.RemoveFromCrewEventData.__new(character.TeamID, {}))
    end)
end

return extension
