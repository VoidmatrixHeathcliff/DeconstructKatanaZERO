local env_path = {"scripts\\?.lua"}
package.path = string.format("%s;%s", package.path, table.concat(env_path, ";"))

local EtherTK       = require("EtherTK")
local EasyGUI       = require("EasyGUI")
local EasyShader    = require("EasyShader")

local OS        = EtherTK.OS
local STB       = EtherTK.STB
local Time      = EtherTK.Time
local JSON      = EtherTK.JSON
local Input     = EtherTK.Input
local ImGUI     = EtherTK.ImGUI
local Input     = EtherTK.Input
local Window    = EtherTK.Window
local OpenGL    = EtherTK.OpenGL
local String    = EtherTK.String

local VAO = nil
local window_width, window_height <const> = 1280, 720
-- 背景图纹理对象，玩家动画纹理对象列表
local texture_backgorund, texture_shield_list = nil, {}
-- 常规渲染 shader 对象，残影渲染 shader 对象
local shader_normal, shader_sketch = nil, nil
-- 玩家位置，玩家在移动时的目标位置
local location_shield, dst_location_shield = OpenGL.Vec2(0, -220), OpenGL.Vec2(0, -220)
-- 残影颜色列表，残影对象列表
local color_list, shadow_list = {OpenGL.Vec3(0.1, 0.3, 0.9), OpenGL.Vec3(0.9, 0.1, 0.8)}, {}
-- 当前新生成的残影使用的颜色索引
local idx_color_list = 0
-- 残影起始透明度
local alpha_shadow_init = 0.3
-- 生成下一帧残影的时间间隔，残影消失的时间间隔，切换残影颜色的时间间隔
local interval_next_shadow, interval_shadow_fade_out, interval_switch_color = 15, 380, 50
-- 生成下一帧残影的计时器，切换残影颜色的计时器
local timer_next_shadow, timer_switch_color = 0, 0
-- 玩家移动速度（px / ms），玩家冲刺总距离
local speed_player, dash_distance_player = 0.75, 150
-- 玩家是否在移动，玩家是否朝向右侧
local is_moving, is_facing_right = false, true
-- 当前动画的帧索引，切换下一帧动画的计时器
local idx_texture_shield, timer_shield_animation = 1, 0
-- 切换下一帧动画的时间间隔
local interval_shield_animation <const> = 100
-- 上次 Tick 时间（用于计算 delta_time）
local last_tick = nil

STB.SetFlipVerticallyOnLoad(true)

-- 二维向量插值
local Lerp = function(vec1, vec2, dist)
    local vec_dir = vec2:sub(vec1)
    dist = math.min(dist, vec_dir:size())
    return OpenGL.Vec2(vec1:add(vec_dir:normalize():mul(dist)))
end

-- 加载图片文件为纹理对象
local LoadTexture = function(path, filter)
    local obj = {id = 0, width = 0, height = 0}
    local image = STB.LoadImage(path)
    if not image then return false end
    local format = OpenGL.RED
    local channels = image:channels()
    if channels == 3 then format = OpenGL.RGB elseif channels == 4 then format = OpenGL.RGBA end
    local width, height = image:size()
    local texture = OpenGL.GenTexture()
    OpenGL.BindTexture(OpenGL.TEXTURE_2D, texture)
    OpenGL.TexParameteri(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_MIN_FILTER, filter)
    OpenGL.TexParameteri(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_MAG_FILTER, filter)
    OpenGL.TexParameteri(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_WRAP_S, OpenGL.CLAMP_TO_EDGE)
    OpenGL.TexParameteri(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_WRAP_T, OpenGL.CLAMP_TO_EDGE)
    OpenGL.PixelStorei(OpenGL.UNPACK_ROW_LENGTH, 0)
    OpenGL.TexImage2D(OpenGL.TEXTURE_2D, 0, OpenGL.RGBA, width, height, format, OpenGL.UNSIGNED_BYTE, image:data())
    obj.id, obj.width, obj.height = texture, width, height
    return true, obj
end

-- 加载 Shader 脚本文件为 Shader 对象
local LoadShader = function(vs_path, fs_path)
    local vs_file = io.open(vs_path) assert(vs_file)
    local fs_file = io.open(fs_path) assert(fs_file)
    local status, result = EasyShader.Create(vs_file:read("*a"), fs_file:read("*a"))
    assert(status, result)  vs_file:close() fs_file:close()
    return result
end

-- 启用当前帧缓冲的 Alpha 混合
local EnableBlend = function()
    OpenGL.Enable(OpenGL.BLEND)
    OpenGL.BlendFunc(OpenGL.SRC_ALPHA, OpenGL.ONE_MINUS_SRC_ALPHA)
    local color_border = OpenGL.Array(OpenGL.FLOAT, {0, 0, 0, 0})
    OpenGL.TexParameterfv(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_BORDER_COLOR, color_border)
end

-- 初始化 AVO
local InitVAO = function()
    local array_data_vao = 
    {
    --  location    texture
        -0.5, 0.5,	0.0, 1.0,
        0.5, -0.5,	1.0, 0.0,
        -0.5, -0.5,	0.0, 0.0,
        
        -0.5, 0.5,	0.0, 1.0,
        0.5, 0.5,	1.0, 1.0,
        0.5, -0.5,	1.0, 0.0
    }
    VAO = OpenGL.GenVertexArray()
    local VBO = OpenGL.GenBuffer()
    OpenGL.BindVertexArray(VAO)
    OpenGL.BindBuffer(OpenGL.ARRAY_BUFFER, VBO)
    OpenGL.BufferData(OpenGL.ARRAY_BUFFER, OpenGL.Array(OpenGL.FLOAT, array_data_vao), OpenGL.STATIC_DRAW)
    OpenGL.VertexAttribPointer(0, 4, OpenGL.FLOAT, false, 4 * OpenGL.SIZE_FLOAT, 0)
    OpenGL.EnableVertexAttribArray(0)
    OpenGL.BindBuffer(OpenGL.ARRAY_BUFFER, 0)
    OpenGL.BindVertexArray(0)
end

-- 渲染场景
local RenderScene = function()
    -- [[ 渲染背景图片 ]]
    shader_normal:Use()
    local model = OpenGL.Mat4(1.0)
    model = OpenGL.TranslateMat(model, OpenGL.Vec3(0, 0, 0))
    model = OpenGL.RotateMat(model, OpenGL.Radians(0), OpenGL.Vec3(0, 0, 1.0))
    model = OpenGL.ScaleMat(model, OpenGL.Vec3(window_width, window_height, 1.0))
    shader_normal:SetMat4fv("model", model)
    local view = OpenGL.Mat4(1.0)
    view = OpenGL.TranslateMat(view, OpenGL.Vec3(0, 0, 0))
    shader_normal:SetMat4fv("view", view)
    local projection = OpenGL.OrthoMat(-window_width / 2, window_width / 2, -window_height / 2, window_height / 2, -1.0, 1.0)
    shader_normal:SetMat4fv("projection", projection)
    shader_normal:Set1f("enhance", 1.5)
    OpenGL.BindTexture(OpenGL.TEXTURE_2D, texture_backgorund.id)
    OpenGL.BindVertexArray(VAO)
    OpenGL.DrawArrays(OpenGL.TRIANGLES, 0, 6)

    local width_shield, height_shield = texture_shield_list[1].width * 2, texture_shield_list[1].height * 2

    -- [[ 渲染残影效果 ]]
    shader_sketch:Use()
    for _, shadow in ipairs(shadow_list) do
        local model = OpenGL.Mat4(1.0)
        model = OpenGL.TranslateMat(model, OpenGL.Vec3(shadow.location:x(), shadow.location:y(), 0))
        model = OpenGL.RotateMat(model, OpenGL.Radians(0), OpenGL.Vec3(0, 0, 1.0))
        local ratio = 1 if not shadow.is_facing_right then ratio = -1 end
        model = OpenGL.ScaleMat(model, OpenGL.Vec3(width_shield * ratio, height_shield, 1.0))
        shader_sketch:SetMat4fv("model", model)
        local view = OpenGL.Mat4(1.0)
        view = OpenGL.TranslateMat(view, OpenGL.Vec3(0, 0, 0))
        shader_sketch:SetMat4fv("view", view)
        local projection = OpenGL.OrthoMat(-window_width / 2, window_width / 2, -window_height / 2, window_height / 2, -1.0, 1.0)
        shader_sketch:SetMat4fv("projection", projection)
        shader_sketch:Set3fv("color", shadow.color)
        shader_sketch:Set1f("alpha", shadow.alpha)
        OpenGL.BindTexture(OpenGL.TEXTURE_2D, shadow.texture.id)
        OpenGL.BindVertexArray(VAO)
        OpenGL.DrawArrays(OpenGL.TRIANGLES, 0, 6)
    end

    -- [[ 渲染角色图片 ]]
    shader_normal:Use()
    local model = OpenGL.Mat4(1.0)
    model = OpenGL.TranslateMat(model, OpenGL.Vec3(location_shield:x(), location_shield:y(), 0))
    model = OpenGL.RotateMat(model, OpenGL.Radians(0), OpenGL.Vec3(0, 0, 1.0))
    local ratio = 1 if not is_facing_right then ratio = -1 end
    model = OpenGL.ScaleMat(model, OpenGL.Vec3(width_shield * ratio, height_shield, 1.0))
    shader_normal:SetMat4fv("model", model)
    local view = OpenGL.Mat4(1.0)
    view = OpenGL.TranslateMat(view, OpenGL.Vec3(0, 0, 0))
    shader_normal:SetMat4fv("view", view)
    local projection = OpenGL.OrthoMat(-window_width / 2, window_width / 2, -window_height / 2, window_height / 2, -1.0, 1.0)
    shader_normal:SetMat4fv("projection", projection)
    shader_normal:Set1f("enhance", 1.25)
    OpenGL.BindTexture(OpenGL.TEXTURE_2D, texture_shield_list[idx_texture_shield].id)
    OpenGL.BindVertexArray(VAO)
    OpenGL.DrawArrays(OpenGL.TRIANGLES, 0, 6)
end

-- 渲染控制台
local RenderConsole = function()
    ImGUI.NewFrame()
    ImGUI.Begin("属性控制台")
    
    if ImGUI.CollapsingHeader("玩家属性", ImGUI.TREENODE_FLAGS_DEFAULT_OPEN) then
        ImGUI.BeginDisabled(is_moving)
        _, speed_player = ImGUI.DragNumber("冲刺速度", speed_player, 0.1, 0.05, 100)
        _, dash_distance_player = ImGUI.DragNumber("冲刺距离", dash_distance_player, 1, 10, 1000)
        ImGUI.EndDisabled()
    end
    if ImGUI.CollapsingHeader("特效属性", ImGUI.TREENODE_FLAGS_DEFAULT_OPEN) then
        ImGUI.BeginDisabled(is_moving)
        _, alpha_shadow_init = ImGUI.DragNumber("起始透明度", alpha_shadow_init, 0.1, 0, 1)
        _, interval_next_shadow = ImGUI.DragInt("生成时间间隔", interval_next_shadow, 1, 0, 10000)
        _, interval_shadow_fade_out = ImGUI.DragInt("完全淡出时长", interval_shadow_fade_out, 1, 0, 10000)
        _, interval_switch_color = ImGUI.DragInt("颜色切换时间间隔", interval_switch_color, 1, 0, 10000)
        ImGUI.Unindent(-3)
        if ImGUI.CollapsingHeader("着色序列", ImGUI.TREENODE_FLAGS_DEFAULT_OPEN) then
            local text_height = ImGUI.GetTextLineHeightWithSpacing()
            for idx, color in ipairs(color_list) do
                local active, tmp_color = false, {r = color:x(), g = color:y(), b = color:z(), a = 1}
                active = ImGUI.ColorEdit("##着色"..idx, tmp_color)
                if active then color:x(tmp_color.r) color:y(tmp_color.g) color:z(tmp_color.b) end
                ImGUI.SameLine()
                if ImGUI.Button("+##"..idx, {x = text_height, y = 0}) then
                    table.insert(color_list, idx + 1, OpenGL.Vec3(0.9, 0.9, 0.9))
                end
                if ImGUI.IsItemHovered() then
                    ImGUI.BeginTooltip()
                    ImGUI.Text("新增")
                    ImGUI.EndTooltip()
                end
                ImGUI.SameLine()
                ImGUI.BeginDisabled(#color_list == 1)
                if ImGUI.Button("-##"..idx, {x = text_height, y = 0}) then
                    table.remove(color_list, idx)
                end
                if ImGUI.IsItemHovered() then
                    ImGUI.BeginTooltip()
                    ImGUI.Text("移除")
                    ImGUI.EndTooltip()
                end
                ImGUI.EndDisabled()
            end
        end
        ImGUI.Indent(-3)
        ImGUI.EndDisabled()
    end
    ImGUI.End()
    ImGUI.RenderFrame()
end

-- 更新 Shield 逻辑
local UpdateShield = function(delta_ms)
    -- 更新角色动画
    timer_shield_animation = timer_shield_animation + delta_ms
    if timer_shield_animation >= interval_shield_animation then
        idx_texture_shield = idx_texture_shield + 1
        if idx_texture_shield > #texture_shield_list then
            idx_texture_shield = 1
        end
        timer_shield_animation = 0
    end
    -- 更新角色位置
    if is_moving then
        location_shield = Lerp(location_shield, dst_location_shield, speed_player * delta_ms)
        if location_shield:sub(dst_location_shield):size() <= 1 then
            timer_next_shadow, is_moving = 0, false
        end
    end
end

-- 更新 FlushEffect 逻辑
local UpdateFlushEffect = function(delta_ms)
    -- 更新残影淡出逻辑
    for _, shadow in ipairs(shadow_list) do
        shadow.alpha = shadow.alpha - delta_ms / interval_shadow_fade_out * (alpha_shadow_init / 1.0)
        if shadow.alpha < 0 then shadow.alpha = 0 end
    end
    -- 更新残影颜色逻辑
    timer_switch_color = timer_switch_color + delta_ms
    if timer_switch_color >= interval_switch_color then
        idx_color_list = idx_color_list + 1
        if idx_color_list > #color_list then
            idx_color_list = 1
        end
        timer_switch_color = 0
    end
    -- 更新残影新增逻辑
    if not is_moving then return end
    timer_next_shadow = timer_next_shadow + delta_ms
    if timer_next_shadow >= interval_next_shadow then
        table.insert(shadow_list, 
        {
            location = OpenGL.Vec2(location_shield),
            texture = texture_shield_list[idx_texture_shield],
            color = color_list[idx_color_list],
            alpha = alpha_shadow_init
        })
        timer_next_shadow = 0
    end
end

-- EasyGUI 帧更新回调
local OnTick = function()
    last_tick = last_tick or Time.GetInitTime()
    local current = Time.GetInitTime()
    local delta_ms = current - last_tick
    last_tick = current
    UpdateShield(delta_ms)  UpdateFlushEffect(delta_ms)
    RenderScene()           RenderConsole()
end

-- EasyGUI 窗口清屏回调
local OnClear = function()
    OpenGL.ClearColor(0, 0, 0, 1)
    OpenGL.Clear(OpenGL.COLOR_BUFFER_BIT)
end

-- EasyGUI 键盘回调
local OnKeyoard = function(event)
    if event == Input.EVENT_KEYDOWN then
        local key = Input.GetKeyCode()
        if key == Input.KEY_A or key == Input.KEY_LEFT then
            if not is_moving then
                dst_location_shield:x(dst_location_shield:x() - dash_distance_player)
                -- 在玩家重新移动时，不仅要重置状态，还需要清空残影对象列表
                is_moving, is_facing_right, shadow_list, idx_color_list = true, false, {}, 1
            end
        elseif key == Input.KEY_D or key == Input.KEY_RIGHT then
            if not is_moving then
                dst_location_shield:x(dst_location_shield:x() + dash_distance_player)
                is_moving, is_facing_right, shadow_list, idx_color_list = true, true, {}, 1
            end
        end
    end
end

-- 程序主函数入口
local __MAIN__ = function()
    EasyGUI.Init("FlashEffect", window_width, window_height, Window.OPENGL)
    InitVAO()   EnableBlend()
    local result = false
    result, texture_backgorund = LoadTexture("resources\\bg.png", OpenGL.NEAREST)           assert(result)
    result, texture_shield_list[1] = LoadTexture("resources\\shield_1.png", OpenGL.NEAREST) assert(result)
    result, texture_shield_list[2] = LoadTexture("resources\\shield_2.png", OpenGL.NEAREST) assert(result)
    result, texture_shield_list[3] = LoadTexture("resources\\shield_3.png", OpenGL.NEAREST) assert(result)
    result, texture_shield_list[4] = LoadTexture("resources\\shield_4.png", OpenGL.NEAREST) assert(result)
    EasyGUI.TickFunc(OnTick)    EasyGUI.ClearFunc(OnClear)  EasyGUI.KeyboardFunc(OnKeyoard)
    shader_normal = LoadShader("scripts\\shader\\Normal.vs", "scripts\\shader\\Normal.fs")
    shader_sketch = LoadShader("scripts\\shader\\Sketch.vs", "scripts\\shader\\Sketch.fs")
    ImGUI.GetIO():add_font_from_ttf_file("C:\\Windows\\Fonts\\msyh.ttc", 18, ImGUI.FONT_GLYPH_RANGES_CHINESEFULL)
    EasyGUI.Mainloop()
end

local status, err_msg = pcall(__MAIN__)
if not status then
    Window.MessageBox(Window.MSGBOX_ERROR, "脚本崩溃", err_msg)
end