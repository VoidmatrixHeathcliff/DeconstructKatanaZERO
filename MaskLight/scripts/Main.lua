local env_path = {"scripts\\?.lua"}
package.path = string.format("%s;%s", package.path, table.concat(env_path, ";"))

local EtherTK       = require("EtherTK")
local EasyGUI       = require("EasyGUI")
local EasyShader    = require("EasyShader")

local OS        = EtherTK.OS
local STB       = EtherTK.STB
local Time      = EtherTK.Time
local JSON      = EtherTK.JSON
local ImGUI     = EtherTK.ImGUI
local Input     = EtherTK.Input
local Window    = EtherTK.Window
local OpenGL    = EtherTK.OpenGL
local String    = EtherTK.String

local VAO
local window_width, window_height <const> = 1280, 720
local texture_backgorund, texture_lightmask, texture_normal, texture_solid
local fbo_light_buffer, texture_light_buffer
local shader_background, shader_light, shader_test
local location_light_A, location_light_B = OpenGL.Vec2(-315, 175), OpenGL.Vec2(-315, -175)
local rotation_light_A, rotation_light_B = 0, 0
local scale_light_A, scale_light_B = OpenGL.Vec2(1, 1), OpenGL.Vec2(1, 1)
local color_light_A, color_light_B = OpenGL.Vec3(1, 0, 0), OpenGL.Vec3(0, 0, 1)
local strength_light_A, strength_light_B = 1, 1
local color_light_ambient, strength_light_ambient = OpenGL.Vec3(1, 1, 1), 1

STB.SetFlipVerticallyOnLoad(true)

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
    OpenGL.BlendFunc(OpenGL.ONE, OpenGL.ONE)
    local color_border = OpenGL.Array(OpenGL.FLOAT, {0, 0, 0, 0})
    OpenGL.TexParameterfv(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_BORDER_COLOR, color_border)
end

-- 创建新的帧缓冲，返回 [FBO] 和 [纹理对象]
local NewFrameBuffer = function()
    local fbo = OpenGL.GenFramebuffer()
    OpenGL.BindFramebuffer(OpenGL.FRAMEBUFFER, fbo)
    local texture = {id = OpenGL.GenTexture(), width = window_width, height = window_height}
    OpenGL.BindTexture(OpenGL.TEXTURE_2D, texture.id)
    OpenGL.TexImage2D(OpenGL.TEXTURE_2D, 0, OpenGL.RGBA, window_width, window_height, OpenGL.RGBA, OpenGL.UNSIGNED_BYTE, nil)
    OpenGL.TexParameteri(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_MIN_FILTER, OpenGL.LINEAR)
    OpenGL.TexParameteri(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_MAG_FILTER, OpenGL.LINEAR)
    OpenGL.FramebufferTexture2D(OpenGL.FRAMEBUFFER, OpenGL.COLOR_ATTACHMENT0, OpenGL.TEXTURE_2D, texture.id, 0)
    local rbo = OpenGL.GenRenderbuffer()
    OpenGL.BindRenderbuffer(OpenGL.RENDERBUFFER, rbo)
    OpenGL.RenderbufferStorage(OpenGL.RENDERBUFFER, OpenGL.DEPTH24_STENCIL8, window_width, window_height)
    OpenGL.FramebufferRenderbuffer(OpenGL.RENDERBUFFER, OpenGL.DEPTH_STENCIL_ATTACHMENT, OpenGL.RENDERBUFFER, rbo)
    local status = OpenGL.CheckFramebufferStatus(OpenGL.FRAMEBUFFER)
    assert(status == OpenGL.FRAMEBUFFER_COMPLETE, string.format("帧缓冲创建失败，状态码: %d", status))
    EnableBlend()
    OpenGL.BindFramebuffer(OpenGL.FRAMEBUFFER, 0)
    return fbo, texture
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
    -- [[ 生成光照纹理 ]]
    OpenGL.BindFramebuffer(OpenGL.FRAMEBUFFER, fbo_light_buffer)
    OpenGL.ClearColor(0, 0, 0, 1)
    OpenGL.Clear(OpenGL.COLOR_BUFFER_BIT)
    shader_light:Use()

    -- 灯光 A
    local model = OpenGL.Mat4(1.0)
    model = OpenGL.TranslateMat(model, OpenGL.Vec3(location_light_A:x(), location_light_A:y(), 0))
    model = OpenGL.RotateMat(model, OpenGL.Radians(rotation_light_A), OpenGL.Vec3(0, 0, 1.0))
    model = OpenGL.ScaleMat(model, OpenGL.Vec3(scale_light_A:x() * texture_lightmask.width, scale_light_A:y() * texture_lightmask.height, 1.0))
    shader_light:SetMat4fv("model", model)
    local view = OpenGL.Mat4(1.0)
    view = OpenGL.TranslateMat(view, OpenGL.Vec3(0, 0, 0))
    shader_light:SetMat4fv("view", view)
    local projection = OpenGL.OrthoMat(-window_width / 2, window_width / 2, -window_height / 2, window_height / 2, -1.0, 1.0)
    shader_light:SetMat4fv("projection", projection)
    shader_light:Set3fv("color", color_light_A)
    shader_light:Set1f("strength", strength_light_A)
    OpenGL.ActiveTexture(OpenGL.TEXTURE0)
    OpenGL.BindTexture(OpenGL.TEXTURE_2D, texture_lightmask.id)
    OpenGL.BindVertexArray(VAO)
    OpenGL.DrawArrays(OpenGL.TRIANGLES, 0, 6)

    -- 灯光 B
    local model = OpenGL.Mat4(1.0)
    model = OpenGL.TranslateMat(model, OpenGL.Vec3(location_light_B:x(), location_light_B:y(), 0))
    model = OpenGL.RotateMat(model, OpenGL.Radians(rotation_light_B), OpenGL.Vec3(0, 0, 1.0))
    model = OpenGL.ScaleMat(model, OpenGL.Vec3(scale_light_B:x() * texture_lightmask.width, scale_light_B:y() * texture_lightmask.height, 1.0))
    shader_light:SetMat4fv("model", model)
    local view = OpenGL.Mat4(1.0)
    view = OpenGL.TranslateMat(view, OpenGL.Vec3(0, 0, 0))
    shader_light:SetMat4fv("view", view)
    local projection = OpenGL.OrthoMat(-window_width / 2, window_width / 2, -window_height / 2, window_height / 2, -1.0, 1.0)
    shader_light:SetMat4fv("projection", projection)
    shader_light:Set3fv("color", color_light_B)
    shader_light:Set1f("strength", strength_light_B)
    OpenGL.ActiveTexture(OpenGL.TEXTURE0)
    OpenGL.BindTexture(OpenGL.TEXTURE_2D, texture_lightmask.id)
    OpenGL.BindVertexArray(VAO)
    OpenGL.DrawArrays(OpenGL.TRIANGLES, 0, 6)

    -- [[ 渲染背景图片 ]]
    OpenGL.BindFramebuffer(OpenGL.FRAMEBUFFER, 0)
    shader_background:Use()
    local model = OpenGL.Mat4(1.0)
    model = OpenGL.TranslateMat(model, OpenGL.Vec3(0, 0, 0))
    model = OpenGL.RotateMat(model, OpenGL.Radians(0), OpenGL.Vec3(0, 0, 1.0))
    model = OpenGL.ScaleMat(model, OpenGL.Vec3(window_width, window_height, 1.0))
    shader_background:SetMat4fv("model", model)
    local view = OpenGL.Mat4(1.0)
    view = OpenGL.TranslateMat(view, OpenGL.Vec3(0, 0, 0))
    shader_background:SetMat4fv("view", view)
    local projection = OpenGL.OrthoMat(-window_width / 2, window_width / 2, -window_height / 2, window_height / 2, -1.0, 1.0)
    shader_background:SetMat4fv("projection", projection)
    shader_background:Set3fv("ambientColor", color_light_ambient)
    shader_background:Set1f("ambientStrength", strength_light_ambient)
    shader_background:Set1i("textureBackgound", 0)
    shader_background:Set1i("textureLight", 1)
    shader_background:Set1i("textureNormal", 2)
    OpenGL.ActiveTexture(OpenGL.TEXTURE0)
    OpenGL.BindTexture(OpenGL.TEXTURE_2D, texture_backgorund.id)
    OpenGL.ActiveTexture(OpenGL.TEXTURE1)
    OpenGL.BindTexture(OpenGL.TEXTURE_2D, texture_light_buffer.id)
    OpenGL.ActiveTexture(OpenGL.TEXTURE2)
    OpenGL.BindTexture(OpenGL.TEXTURE_2D, texture_normal.id)
    OpenGL.BindVertexArray(VAO)
    OpenGL.DrawArrays(OpenGL.TRIANGLES, 0, 6)

    -- [[ 测试代码 ]]
    -- OpenGL.BindFramebuffer(OpenGL.FRAMEBUFFER, 0)
    -- shader_test:Use()
    -- local model = OpenGL.Mat4(1.0)
    -- model = OpenGL.TranslateMat(model, OpenGL.Vec3(0, 0, 0))
    -- model = OpenGL.RotateMat(model, OpenGL.Radians(0), OpenGL.Vec3(0, 0, 1.0))
    -- model = OpenGL.ScaleMat(model, OpenGL.Vec3(window_width, window_height, 1.0))
    -- shader_test:SetMat4fv("model", model)
    -- local view = OpenGL.Mat4(1.0)
    -- view = OpenGL.TranslateMat(view, OpenGL.Vec3(0, 0, 0))
    -- shader_test:SetMat4fv("view", view)
    -- local projection = OpenGL.OrthoMat(-window_width / 2, window_width / 2, -window_height / 2, window_height / 2, -1.0, 1.0)
    -- shader_test:SetMat4fv("projection", projection)
    -- OpenGL.ActiveTexture(OpenGL.TEXTURE0)
    -- OpenGL.BindTexture(OpenGL.TEXTURE_2D, texture_backgorund.id)
    -- OpenGL.ActiveTexture(OpenGL.TEXTURE1)
    -- OpenGL.BindTexture(OpenGL.TEXTURE_2D, texture_solid.id)
    -- OpenGL.BindVertexArray(VAO)
    -- OpenGL.DrawArrays(OpenGL.TRIANGLES, 0, 6)
end

-- 渲染控制台
local RenderConsole = function()
    ImGUI.NewFrame()
    ImGUI.Begin("灯光控制台")
    if ImGUI.CollapsingHeader("环境光", ImGUI.TREENODE_FLAGS_DEFAULT_OPEN) then
        local active, color = false, {r = color_light_ambient:x(), g = color_light_ambient:y(), b = color_light_ambient:z(), a = 1}
        active = ImGUI.ColorEdit("颜色##环境光", color)
        if active then color_light_ambient:x(color.r) color_light_ambient:y(color.g) color_light_ambient:z(color.b) end
        active, strength_light_ambient = ImGUI.DragNumber("强度##环境光", strength_light_ambient, 1, 0, 10000)
    end
    if ImGUI.CollapsingHeader("灯光 A", ImGUI.TREENODE_FLAGS_DEFAULT_OPEN) then
        local active, x, y = ImGUI.DragNumber2("位置##A", location_light_A:x(), location_light_A:y())
        if active then location_light_A:x(x) location_light_A:y(y) end
        active, rotation_light_A = ImGUI.DragNumber("旋转##A", rotation_light_A)
        local active, x, y = ImGUI.DragNumber2("缩放##A", scale_light_A:x(), scale_light_A:y())
        if active then scale_light_A:x(x) scale_light_A:y(y) end
        local active, color = false, {r = color_light_A:x(), g = color_light_A:y(), b = color_light_A:z(), a = 1}
        active = ImGUI.ColorEdit("颜色##A", color)
        if active then color_light_A:x(color.r) color_light_A:y(color.g) color_light_A:z(color.b) end
        active, strength_light_A = ImGUI.DragNumber("强度##A", strength_light_A, 0.1, 0, 100)
    end
    if ImGUI.CollapsingHeader("灯光 B", ImGUI.TREENODE_FLAGS_DEFAULT_OPEN) then
        local active, x, y = ImGUI.DragNumber2("位置##B", location_light_B:x(), location_light_B:y())
        if active then location_light_B:x(x) location_light_B:y(y) end
        active, rotation_light_B = ImGUI.DragNumber("旋转##B", rotation_light_B)
        local active, x, y = ImGUI.DragNumber2("缩放##B", scale_light_B:x(), scale_light_B:y())
        if active then scale_light_B:x(x) scale_light_B:y(y) end
        local active, color = false, {r = color_light_B:x(), g = color_light_B:y(), b = color_light_B:z(), a = 1}
        active = ImGUI.ColorEdit("颜色##B", color)
        if active then color_light_B:x(color.r) color_light_B:y(color.g) color_light_B:z(color.b) end
        active, strength_light_B = ImGUI.DragNumber("强度##B", strength_light_B, 0.1, 0, 100)
    end
    ImGUI.End()
    ImGUI.RenderFrame()
end

-- EasyGUI 帧更新回调
local OnTick = function()
    RenderScene()
    RenderConsole()
end

-- EasyGUI 窗口清屏回调
local OnClear = function()
    OpenGL.ClearColor(0, 0, 0, 1)
    OpenGL.Clear(OpenGL.COLOR_BUFFER_BIT)
end

-- 程序主函数入口
local __MAIN__ = function()
    EasyGUI.Init("MaskLight", window_width, window_height, Window.OPENGL)
    InitVAO()   EnableBlend()
    local result = false
    result, texture_backgorund = LoadTexture("resources\\bg.png", OpenGL.NEAREST)   assert(result)
    result, texture_lightmask = LoadTexture("resources\\mask.png", OpenGL.LINEAR)   assert(result)
    result, texture_normal = LoadTexture("resources\\normal.png", OpenGL.NEAREST)   assert(result)
    result, texture_solid = LoadTexture("resources\\solid.png", OpenGL.LINEAR)      assert(result)
    fbo_light_buffer, texture_light_buffer = NewFrameBuffer()
    EasyGUI.TickFunc(OnTick)    EasyGUI.ClearFunc(OnClear)
    shader_light = LoadShader("scripts\\shader\\Light.vs", "scripts\\shader\\Light.fs")
    shader_background = LoadShader("scripts\\shader\\Background.vs", "scripts\\shader\\Background.fs")
    shader_test = LoadShader("scripts\\shader\\Test.vs", "scripts\\shader\\Test.fs")
    ImGUI.GetIO():add_font_from_ttf_file("C:\\Windows\\Fonts\\msyh.ttc", 18, ImGUI.FONT_GLYPH_RANGES_CHINESEFULL)
    EasyGUI.Mainloop()
end

local status, err_msg = pcall(__MAIN__)
if not status then
    Window.MessageBox(Window.MSGBOX_ERROR, "脚本崩溃", err_msg)
end