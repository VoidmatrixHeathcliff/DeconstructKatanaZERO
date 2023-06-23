local __MODULE__ = {}

local EtherTK   = require("EtherTK")

local Soloud    = EtherTK.Soloud

local metatable = 
{
    __index = 
    {
        play = function(self, audio)
            return self.bus:play(audio)
        end,
        set_volume = function(self, val)
            self.volume = val
        end,
        get_approximate_volume = function(self, channel)
            return self.bus:get_approximate_volume(channel) * self.volume
        end
    }
}

__MODULE__.Create = function()
    local obj = 
    {
        volume = 1.0,
        bus = Soloud.Bus(),
    }
    setmetatable(obj, metatable)
    return obj
end

return __MODULE__