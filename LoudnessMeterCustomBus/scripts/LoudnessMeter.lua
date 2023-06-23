local __MODULE__ = {}

local EtherTK   = require("EtherTK")

local Time      = EtherTK.Time
local ImGUI     = EtherTK.ImGUI
local Soloud    = EtherTK.Soloud
local Graphic   = EtherTK.Graphic

local size <const> = {x = 85, y = 280}
local color_background <const> = {r = 0.188, g = 0.208, b = 0.275, a = 1}
local color_background_slot <const> = {r = 0.1, g = 0.125, b = 0.195, a = 1}
local size_slot <const> = {x = 14, y = 260}
local slot_spacing <const> = 8
local color_ldn_small <const> = {r = 0.24, g = 0.7, b = 0.44, a = 1}
local color_ldn_medium <const> = {r = 0.99, g = 0.78, b = 0, a = 1}
local color_ldn_large <const> = {r = 0.77, g = 0.24, b = 0.26, a = 1}
local slot_padding <const> = 2
local slot_valid_zoon_h_ratio <const> = 0.4
local min_loudness, max_loudness <const> = -48, 0
local speed_slow_fall_valid <const> = 6
local speed_slow_fall_invalid <const> = speed_slow_fall_valid * (-6 - min_loudness) / 6
local scale_margin <const> = 2
local scale_width, scale_font_size <const> = 4, 12
local color_scale <const> = {r = 135, g = 135, b = 135, a = 255}
local color_scale_text <const> = {r = 135, g = 135, b = 135, a = 255}
local scale_text_texture_6, scale_text_texture_3, scale_text_texture_max, scale_text_texture_min
local scale_text_texture_6_size, scale_text_texture_3_size, scale_text_texture_max_size, scale_text_texture_min_size = {}, {}, {}, {}

local _CheckAndLoadFontTexture = function()
    if scale_text_texture_6 then return end
    local font = Graphic.FontFile("C:\\Windows\\Fonts\\msyh.ttc", scale_font_size)
    assert(font, "响度计标尺刻度字体加载失败")
    scale_text_texture_6 = Graphic.CreateTexture(Graphic.TextImageQuality(font, "6", color_scale_text))
    scale_text_texture_3 = Graphic.CreateTexture(Graphic.TextImageQuality(font, "3", color_scale_text))
    scale_text_texture_max = Graphic.CreateTexture(Graphic.TextImageQuality(font, tostring(-max_loudness), color_scale_text))
    scale_text_texture_min = Graphic.CreateTexture(Graphic.TextImageQuality(font, tostring(-min_loudness), color_scale_text))
    scale_text_texture_6_size.x, scale_text_texture_6_size.y = scale_text_texture_6:size()
    scale_text_texture_3_size.x, scale_text_texture_3_size.y = scale_text_texture_3:size()
    scale_text_texture_max_size.x, scale_text_texture_max_size.y = scale_text_texture_max:size()
    scale_text_texture_min_size.x, scale_text_texture_min_size.y = scale_text_texture_min:size()
end
local _Lerp = function(a, b, step)
    if a + step < b then return b end
    return a + step
end

local _RenderLoudnessSlotContent = function(draw_list, loudness, x, y)
    if loudness >= min_loudness then
        if loudness > max_loudness then loudness = max_loudness end
        -- 矩形右下角顶点坐标
        local pt_rb = {x = x + size_slot.x - slot_padding, y = y + size_slot.y - slot_padding * 2 + 1}
        -- 矩形左上角顶点坐标
        local pt_lt = {x = x + slot_padding, 
            y = pt_rb.y - (loudness - min_loudness) / (-6 - min_loudness) * (size_slot.y - 2 * slot_padding) * (1 - slot_valid_zoon_h_ratio) + 1}
        draw_list:add_rect_filled(pt_lt, pt_rb, color_ldn_small)
        if loudness > -6 then
            pt_rb.y = y + (size_slot.y - slot_padding * 2) * slot_valid_zoon_h_ratio + 1
            pt_lt.y = pt_rb.y - (loudness + 6) / 6 * (size_slot.y - slot_padding * 2) * slot_valid_zoon_h_ratio + 1
            draw_list:add_rect_filled(pt_lt, pt_rb, color_ldn_medium)
        end
        if loudness > -3 then
            pt_rb.y = y + (size_slot.y - slot_padding * 2) * slot_valid_zoon_h_ratio / 2 + 1
            pt_lt.y = pt_rb.y - (loudness + 3) / 3 * (size_slot.y - slot_padding * 2) * slot_valid_zoon_h_ratio / 2 + 1
            draw_list:add_rect_filled(pt_lt, pt_rb, color_ldn_large)
        end
    end
end

local metatable = 
{
    __index = 
    {
        render = function(self)
            _CheckAndLoadFontTexture()
            -- [[ 更新 Tick 时间间隔 ]]
            if not self.last_tick then self.last_tick = Time.GetInitTime() end
            local current_time = Time.GetInitTime()
            local delta_time = (current_time - self.last_tick) / 1000
            self.last_tick = current_time
            -- [[ 计算组件位置和槽位位置 ]]
            ImGUI.BeginGroup()
            ImGUI.Text(self.id)
            local pos_widget_x, pos_widget_y = ImGUI.GetCursorScreenPos()
            local pos_l_chan_x = pos_widget_x + size.x / 2 - slot_spacing / 2 - size_slot.x
            local pos_l_chan_y = pos_widget_y + (size.y - size_slot.y) / 2
            local pos_r_chan_x = pos_l_chan_x + size_slot.x + slot_spacing
            local pos_r_chan_y = pos_l_chan_y
            ImGUI.Dummy(size)
            -- [[ 开始响度计组件内容绘制 ]]
            local draw_list = ImGUI.GetWindowDrawList()
            -- 绘制响度计背景色
            draw_list:add_rect_filled({x = pos_widget_x, y = pos_widget_y}, {x = pos_widget_x + size.x, y = pos_widget_y + size.y}, color_background)
            -- 绘制左右声道槽位背景色
            draw_list:add_rect_filled({x = pos_l_chan_x, y = pos_l_chan_y}, {x = pos_l_chan_x + size_slot.x, y = pos_l_chan_y + size_slot.y}, color_background_slot)
            draw_list:add_rect_filled({x = pos_r_chan_x, y = pos_r_chan_y}, {x = pos_r_chan_x + size_slot.x, y = pos_r_chan_y + size_slot.y}, color_background_slot)
            -- 绘制左右声道响度条
            local ldn_l, ldn_r
            if self.bus == Soloud then
                ldn_l = 20 * math.log(self.bus.GetApproximateVolume(0), 10)
                ldn_r = 20 * math.log(self.bus.GetApproximateVolume(1), 10)
            else
                ldn_l = 20 * math.log(self.bus:get_approximate_volume(0), 10)
                ldn_r = 20 * math.log(self.bus:get_approximate_volume(1), 10)
            end
            local delta_ldn_l, delta_ldn_r = -speed_slow_fall_valid * delta_time, -speed_slow_fall_valid * delta_time
            if self.dummy_loudness.l < -6 then delta_ldn_l = -speed_slow_fall_invalid * delta_time end
            if self.dummy_loudness.r < -6 then delta_ldn_r = -speed_slow_fall_invalid * delta_time end
            if ldn_l >= self.dummy_loudness.l then self.dummy_loudness.l = ldn_l else self.dummy_loudness.l = _Lerp(self.dummy_loudness.l, ldn_l, delta_ldn_l) end
            if ldn_r >= self.dummy_loudness.r then self.dummy_loudness.r = ldn_r else self.dummy_loudness.r = _Lerp(self.dummy_loudness.r, ldn_r, delta_ldn_r) end
            _RenderLoudnessSlotContent(draw_list, self.dummy_loudness.l, pos_l_chan_x, pos_l_chan_y)
            _RenderLoudnessSlotContent(draw_list, self.dummy_loudness.r, pos_r_chan_x, pos_r_chan_y)
            -- 绘制响度标尺刻度
            local p1, p2 = {x = pos_r_chan_x + size_slot.x + scale_margin, y = pos_r_chan_y}, {x = 0, y = 0}
            p2.x, p2.y = p1.x + scale_width, p1.y
            draw_list:add_line(p1, p2)
            draw_list:add_image(scale_text_texture_max, {x = p2.x + scale_margin, y = p2.y - scale_text_texture_max_size.y / 2}, 
                {x = p2.x + scale_margin + scale_text_texture_max_size.x, y = p2.y + scale_text_texture_max_size.y / 2})
            p1.y = p1.y + size_slot.y * slot_valid_zoon_h_ratio / 2
            p2.y = p1.y
            draw_list:add_line(p1, p2)
            draw_list:add_image(scale_text_texture_3, {x = p2.x + scale_margin, y = p2.y - scale_text_texture_3_size.y / 2}, 
                {x = p2.x + scale_margin + scale_text_texture_3_size.x, y = p2.y + scale_text_texture_3_size.y / 2})
            p1.y = p1.y + size_slot.y * slot_valid_zoon_h_ratio / 2
            p2.y = p1.y
            draw_list:add_line(p1, p2)
            draw_list:add_image(scale_text_texture_6, {x = p2.x + scale_margin, y = p2.y - scale_text_texture_6_size.y / 2}, 
                {x = p2.x + scale_margin + scale_text_texture_6_size.x, y = p2.y + scale_text_texture_6_size.y / 2})
            p1.y = pos_r_chan_y + size_slot.y - slot_padding
            p2.y = p1.y
            draw_list:add_line(p1, p2)
            draw_list:add_image(scale_text_texture_min, {x = p2.x + scale_margin, y = p2.y - scale_text_texture_min_size.y / 2}, 
                {x = p2.x + scale_margin + scale_text_texture_min_size.x, y = p2.y + scale_text_texture_min_size.y / 2})
            ImGUI.EndGroup()
        end
    }
}

__MODULE__.Create = function(id, bus)
    local obj = 
    {
        id = id,
        bus = bus,
        last_tick = nil,
        dummy_loudness = {l = min_loudness, r = min_loudness}
    }
    setmetatable(obj, metatable)
    return obj
end

return __MODULE__