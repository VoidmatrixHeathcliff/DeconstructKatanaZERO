local env_path = {"scripts\\?.lua"}
package.path = string.format("%s;%s", package.path, table.concat(env_path, ";"))

local EtherTK       = require("EtherTK")
local EasyShader    = require("EasyShader")

local OS        = EtherTK.OS
local STB       = EtherTK.STB
local Input     = EtherTK.Input
local ImGUI     = EtherTK.ImGUI
local Window    = EtherTK.Window
local OpenGL    = EtherTK.OpenGL

local VAO
local texture_src, texture_dst, fbo_dst
local shader_process
local src_path <const> = "workspace\\src.png"
local dst_path <const> = "workspace\\dst.png"
local window_width, window_height <const> = 1280, 720

STB.SetFlipVerticallyOnLoad(true)
STB.SetFlipVerticallyOnWrite(true)

-- 上传纹理数据
local UploadTextureData = function(data, width, height, format, filter)
    local obj = {id = 0, width = 0, height = 0}
    local texture = OpenGL.GenTexture()
    OpenGL.BindTexture(OpenGL.TEXTURE_2D, texture)
    OpenGL.TexParameteri(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_MIN_FILTER, filter)
    OpenGL.TexParameteri(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_MAG_FILTER, filter)
    OpenGL.TexParameteri(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_WRAP_S, OpenGL.CLAMP_TO_EDGE)
    OpenGL.TexParameteri(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_WRAP_T, OpenGL.CLAMP_TO_EDGE)
    OpenGL.PixelStorei(OpenGL.UNPACK_ROW_LENGTH, 0)
    OpenGL.TexImage2D(OpenGL.TEXTURE_2D, 0, OpenGL.RGBA, width, height, format, OpenGL.UNSIGNED_BYTE, data)
    obj.id, obj.width, obj.height = texture, width, height
    return obj
end

-- 加载图片文件为纹理对象
local LoadTexture = function(path, filter)
    local image = STB.LoadImage(path)
    if not image then return false end
    local format = OpenGL.RED
    local channels = image:channels()
    if channels == 3 then format = OpenGL.RGB elseif channels == 4 then format = OpenGL.RGBA end
    local width, height = image:size()
    return true, UploadTextureData(image:data(), width, height, format, filter)
end

-- 加载 Shader 脚本文件为 Shader 对象
local LoadShader = function(vs_path, fs_path)
    local vs_file = io.open(vs_path) assert(vs_file)
    local fs_file = io.open(fs_path) assert(fs_file)
    local status, result = EasyShader.Create(vs_file:read("*a"), fs_file:read("*a"))
    assert(status, result)  vs_file:close() fs_file:close()
    return result
end

-- 创建新的帧缓冲，返回 [FBO] 和 [纹理对象]
local NewFrameBuffer = function(width, height)
    local fbo = OpenGL.GenFramebuffer()
    OpenGL.BindFramebuffer(OpenGL.FRAMEBUFFER, fbo)
    local texture = {id = OpenGL.GenTexture(), width = width, height = height}
    OpenGL.BindTexture(OpenGL.TEXTURE_2D, texture.id)
    OpenGL.TexImage2D(OpenGL.TEXTURE_2D, 0, OpenGL.RGBA, width, height, OpenGL.RGBA, OpenGL.UNSIGNED_BYTE, nil)
    OpenGL.TexParameteri(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_MIN_FILTER, OpenGL.LINEAR)
    OpenGL.TexParameteri(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_MAG_FILTER, OpenGL.LINEAR)
    OpenGL.FramebufferTexture2D(OpenGL.FRAMEBUFFER, OpenGL.COLOR_ATTACHMENT0, OpenGL.TEXTURE_2D, texture.id, 0)
    local rbo = OpenGL.GenRenderbuffer()
    OpenGL.BindRenderbuffer(OpenGL.RENDERBUFFER, rbo)
    OpenGL.RenderbufferStorage(OpenGL.RENDERBUFFER, OpenGL.DEPTH24_STENCIL8, width, height)
    OpenGL.FramebufferRenderbuffer(OpenGL.RENDERBUFFER, OpenGL.DEPTH_STENCIL_ATTACHMENT, OpenGL.RENDERBUFFER, rbo)
    local status = OpenGL.CheckFramebufferStatus(OpenGL.FRAMEBUFFER)
    assert(status == OpenGL.FRAMEBUFFER_COMPLETE, string.format("帧缓冲创建失败，状态码: %d", status))
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

-- 启用当前帧缓冲的 Alpha 混合
local EnableBlend = function()
    OpenGL.Enable(OpenGL.BLEND)
    OpenGL.BlendFunc(OpenGL.ONE, OpenGL.ONE)
    local color_border = OpenGL.Array(OpenGL.FLOAT, {0, 0, 0, 0})
    OpenGL.TexParameterfv(OpenGL.TEXTURE_2D, OpenGL.TEXTURE_BORDER_COLOR, color_border)
end

-- 绘制蒙版纹理
local DrawMaskTexture = function(texture)
    OpenGL.ClearColor(0, 0, 0, 0)   OpenGL.Clear(OpenGL.COLOR_BUFFER_BIT)
    shader_process:Use()
    local model = OpenGL.Mat4(1.0)
    model = OpenGL.TranslateMat(model, OpenGL.Vec3(0, 0, 0))
    model = OpenGL.RotateMat(model, OpenGL.Radians(0), OpenGL.Vec3(0, 0, 1.0))
    model = OpenGL.ScaleMat(model, OpenGL.Vec3(texture_dst.width, texture_dst.height, 1.0))
    shader_process:SetMat4fv("model", model)
    local view = OpenGL.Mat4(1.0)
    view = OpenGL.TranslateMat(view, OpenGL.Vec3(0, 0, 0))
    shader_process:SetMat4fv("view", view)
    local projection = OpenGL.OrthoMat(-texture_dst.width / 2, texture_dst.width / 2, -texture_dst.height / 2, texture_dst.height / 2, -1.0, 1.0)
    shader_process:SetMat4fv("projection", projection)
    OpenGL.ActiveTexture(OpenGL.TEXTURE0)
    OpenGL.BindTexture(OpenGL.TEXTURE_2D, texture.id)
    OpenGL.BindVertexArray(VAO)
    OpenGL.DrawArrays(OpenGL.TRIANGLES, 0, 6)
end

-- 计算并返回蒙版数据
local GenerateMaskData = function()
    OpenGL.BindFramebuffer(OpenGL.FRAMEBUFFER, fbo_dst)
    OpenGL.Viewport(0, 0, texture_dst.width, texture_dst.height)
    DrawMaskTexture(texture_src)
    return OpenGL.ReadPixels(0, 0, texture_dst.width, texture_dst.height, OpenGL.RGBA, OpenGL.UNSIGNED_BYTE, texture_dst.width * texture_dst.height * 4)
end

-- 测试 STB 图片写入
local TestSTBImageWrite = function()
    local image = STB.LoadImage(src_path)
    local width, height = image:size()
    STB.WritePNG(dst_path, width, height, 4, image:data(), width * 4)
    -- STB.WriteJPG(dst_path, width, height, 4, image:data(), 100)
    os.exit(0)
end

-- 程序主函数入口
local __MAIN__ = function()
    -- TestSTBImageWrite()
    Window.Create("MaskGenerator", {x = Window.CENTER_POSITION, y = Window.CENTER_POSITION, w = window_width, h = window_height}, Window.OPENGL)  
    InitVAO()   EnableBlend()
    _, texture_src          = LoadTexture(src_path, OpenGL.NEAREST)     assert(_)
    fbo_dst, texture_dst    = NewFrameBuffer(texture_src.width, texture_src.height)
    shader_process          = LoadShader("scripts\\shader\\Process.vs", "scripts\\shader\\Process.fs")
    local mask_data         = GenerateMaskData()
    assert(STB.WritePNG(dst_path, texture_src.width, texture_src.height, 4, mask_data, texture_src.width * 4), "写入图片失败")
    local texture_passback = UploadTextureData(mask_data, texture_src.width, texture_src.height, OpenGL.RGBA, OpenGL.NEAREST)
    -- while true do 
    --     while Input.UpdateEvent() do end
    --     OpenGL.Viewport(0, 0, window_width, window_height)
    --     OpenGL.ClearColor(0, 0, 0, 1)
    --     OpenGL.BindFramebuffer(OpenGL.FRAMEBUFFER, 0)
    --     DrawMaskTexture(texture_passback) Window.Update() 
    -- end
    OpenGL.DeletePixels(mask_data)
end

local status, err_msg = pcall(__MAIN__)
if not status then
    Window.MessageBox(Window.MSGBOX_ERROR, "脚本崩溃", err_msg)
end