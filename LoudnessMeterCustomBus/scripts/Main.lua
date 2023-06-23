local env_path = {"scripts\\?.lua"}
package.path = string.format("%s;%s", package.path, table.concat(env_path, ";"))

local EtherTK       = require("EtherTK")
local EasyGUI       = require("EasyGUI")
local FuckBus       = require("FuckBus")
local LoudnessMeter = require("LoudnessMeter")

local OS        = EtherTK.OS
local Time      = EtherTK.Time
local JSON      = EtherTK.JSON
local ImGUI     = EtherTK.ImGUI
local Input     = EtherTK.Input
local Soloud    = EtherTK.Soloud
local Window    = EtherTK.Window
local String    = EtherTK.String
local Graphic   = EtherTK.Graphic

local texture_list = {}
local window_width, window_height <const> = 1280, 720
local render_rect <const> = {x = 0, y = 0, w = window_width, h = window_height}
local bus_bgm, wave_bgm, bus_sfx
local handle_bus_master, handle_bus_bgm, handle_bus_sfx, handle_wave
local wave_sfx_ParadoxEngine, wave_sfx_ThorGunship
local lm_master, lm_bgm, lm_sfx
local interval_fade, interval_show <const> = 1500, 4500
local point_ms_ParadoxEngine, point_ms_ThorGunship <const> = 32500, 35500
local timer_point_ParadoxEngine, timer_point_ThorGunship = 0, 0
local is_played_ParadoxEngine, is_played_ThorGunship = false, false
local idx_current_texture, idx_next_texture = 1, 2
local timer_fade, timer_show = 0, 0
local is_fading = false
local delta_time, last_tick = 0, nil
local volume_bus_master, volume_bus_bgm, volume_bus_sfx = 0.95, 1.4, 1.4
local volume_BGM, volume_ParadoxEngine, volume_ThorGunship = 1, 1, 2

-- 更新语音播放
local UpdateVoice = function()
    timer_point_ParadoxEngine = timer_point_ParadoxEngine + delta_time
    timer_point_ThorGunship = timer_point_ThorGunship + delta_time
    if not is_played_ParadoxEngine and timer_point_ParadoxEngine >= point_ms_ParadoxEngine then
        local handle = bus_sfx:play(wave_sfx_ParadoxEngine)
        Soloud.SetVolume(handle, volume_ParadoxEngine)
        is_played_ParadoxEngine = true
    end
    if not is_played_ThorGunship and timer_point_ThorGunship >= point_ms_ThorGunship then
        local handle = bus_sfx:play(wave_sfx_ThorGunship)
        Soloud.SetVolume(handle, volume_ThorGunship)
        is_played_ThorGunship = true
    end
end

-- 渲染场景
local RenderScene = function()
    timer_show = timer_show + delta_time
    if timer_show >= interval_show then
        is_fading, timer_show = true, 0
    end

    if is_fading then
        timer_fade = timer_fade + delta_time
        local delta_alpha = timer_fade / interval_fade * 255
        if delta_alpha > 255 then delta_alpha = 255 end
        texture_list[idx_current_texture]:set_alpha(255 - delta_alpha)
        texture_list[idx_next_texture]:set_alpha(delta_alpha)
        if timer_fade >= interval_fade then
            is_fading, timer_fade = false, 0
            idx_current_texture = idx_next_texture
            idx_next_texture = idx_next_texture + 1
            if idx_next_texture > #texture_list then
                idx_next_texture = 1
            end
        end
    end

    Graphic.RenderTexture(texture_list[idx_current_texture], render_rect)
    if is_fading then
        Graphic.RenderTexture(texture_list[idx_next_texture], render_rect)
    end
end

-- 渲染控制台
local RenderConsole = function()
    ImGUI.NewFrame()
    ImGUI.Begin("音频控制台")
    lm_master:render()  ImGUI.SameLine()
    lm_bgm:render()     ImGUI.SameLine()
    lm_sfx:render()     ImGUI.SameLine()
    ImGUI.BeginChild("音频控制区", {x = 0, y = 0}, true)
    if not is_played_ParadoxEngine then
        ImGUI.Text(string.format("距离悖论引擎时停就绪还有：%d 秒", 
            math.floor((point_ms_ParadoxEngine - timer_point_ParadoxEngine) / 1000)))
    else
        ImGUI.Text("时间停止已启动！")
    end
    local width_drag_widget <const> = 300
    ImGUI.SetNextItemWidth(width_drag_widget)
    _, volume_bus_master = ImGUI.DragNumber("Master Bus Volume", volume_bus_master, 0.1, 0, 100, "%.2f", ImGUI.SLIDER_FLAGS_ALWAYS_CLAMP)
    Soloud.SetGlobalVolume(volume_bus_master)
    ImGUI.SetNextItemWidth(width_drag_widget)
    _, volume_bus_bgm = ImGUI.DragNumber("BGM Bus Volume", volume_bus_bgm, 0.1, 0, 100, "%.2f", ImGUI.SLIDER_FLAGS_ALWAYS_CLAMP)
    Soloud.SetVolume(handle_bus_bgm, volume_bus_bgm)    bus_bgm:set_volume(volume_bus_bgm)
    ImGUI.SetNextItemWidth(width_drag_widget)
    _, volume_bus_sfx = ImGUI.DragNumber("Voice Bus Volume", volume_bus_sfx, 0.1, 0, 100, "%.2f", ImGUI.SLIDER_FLAGS_ALWAYS_CLAMP)
    Soloud.SetVolume(handle_bus_sfx, volume_bus_sfx)    bus_sfx:set_volume(volume_bus_sfx)
    ImGUI.SetNextItemWidth(width_drag_widget)
    _, volume_BGM = ImGUI.DragNumber("BGM Wave Volume", volume_BGM, 0.1, 0, 100, "%.2f", ImGUI.SLIDER_FLAGS_ALWAYS_CLAMP)
    Soloud.SetVolume(handle_wave, volume_BGM)
    ImGUI.SetNextItemWidth(width_drag_widget)
    _, volume_ParadoxEngine = ImGUI.DragNumber("ParadoxEngine Voice Volume", volume_ParadoxEngine, 0.1, 0, 100, "%.2f", ImGUI.SLIDER_FLAGS_ALWAYS_CLAMP)
    ImGUI.SetNextItemWidth(width_drag_widget)
    _, volume_ThorGunship = ImGUI.DragNumber("ThorGunship Voice Volume", volume_ThorGunship, 0.1, 0, 100, "%.2f", ImGUI.SLIDER_FLAGS_ALWAYS_CLAMP)
    ImGUI.EndChild()
    ImGUI.End()
    ImGUI.RenderFrame()
end

-- EasyGUI 帧更新回调
local OnTick = function()
    if not last_tick then
        last_tick = Time.GetInitTime() 
    end
    local current = Time.GetInitTime()
    delta_time = current - last_tick
    last_tick = current

    UpdateVoice()
    RenderScene()
    RenderConsole()
end

-- EasyGUI 窗口清屏回调
local OnClear = function()
    Window.Clear()
end

-- 加载图片文件到纹理列表
local LoadImageFiles = function()
    for i= 1, 5 do
        local image = Graphic.ImageFile(string.format("resources\\%d.png", i))
        assert(image, string.format("加载图片 %d.png 失败", i))
        texture_list[i] = Graphic.CreateTexture(image)
    end
end

-- 加载并初始化音频
local InitAudio = function()
    Soloud.SetPostClipScaler(1.0)
    bus_bgm, bus_sfx = FuckBus.Create(), FuckBus.Create()
    wave_bgm, wave_sfx_ParadoxEngine, wave_sfx_ThorGunship = Soloud.Wav(), Soloud.Wav(), Soloud.Wav()
    lm_master = LoudnessMeter.Create("Master:", Soloud)
    lm_bgm = LoudnessMeter.Create("BGM:", bus_bgm)
    lm_sfx = LoudnessMeter.Create("Voice:", bus_sfx)
    assert(wave_bgm:load("resources\\BGM.mp3"), "背景音乐加载失败")
    assert(wave_sfx_ParadoxEngine:load("resources\\ParadoxEngine.wav"), "悖论引擎音效加载失败")
    assert(wave_sfx_ThorGunship:load("resources\\ThorGunship.wav"), "雷神炮艇音效加载失败")
    handle_bus_bgm = Soloud.Play(bus_bgm.bus)
    handle_bus_sfx = Soloud.Play(bus_sfx.bus)
    handle_wave = bus_bgm:play(wave_bgm)
    bus_bgm.bus:set_visualization_enable(true)  bus_sfx.bus:set_visualization_enable(true)
end

-- 程序主函数入口
local __MAIN__ = function()
    EasyGUI.Init("LoudnessMeter", window_width, window_height)
    InitAudio()     LoadImageFiles()    EasyGUI.TickFunc(OnTick)    EasyGUI.ClearFunc(OnClear)
    ImGUI.GetIO():add_font_from_ttf_file("C:\\Windows\\Fonts\\msyh.ttc", 18, ImGUI.FONT_GLYPH_RANGES_CHINESEFULL)
    EasyGUI.Mainloop()
end

local status, err_msg = pcall(__MAIN__)
if not status then
    Window.MessageBox(Window.MSGBOX_ERROR, "脚本崩溃", err_msg)
end