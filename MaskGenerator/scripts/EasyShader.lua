--[============================================================================[

    这里只有一个函数：EasyShader.Create，
    它渴望你传入顶点着色器代码和片段着色器代码，你可以从文件中读取或直接编写字面值，
    确保在调用它之前你的 OpenGL 窗口已经准备好并配置完成，否则可能 【寄】！

    如果创建成功，则返回 Shader 对象，成员函数有两个（类）：

    Use()：使用当前着色器进行渲染；
    Setxxx(name, val ...)：这是一系列函数，第一个参数是 Uniform 的名字，
        第二个及后续可能存在的参数是你需要设置的值，譬如 2 个浮点数，1 个三维向量；

    示例代码：
    local EasyShader = require("EasyShader")
    local status, result  = EasyShader.Create("...", "...")
    if not status then print("Error:", result) end
    result:Use()    result:Set2f("position", x, y)

--]============================================================================]

local __MODULE__ = {}

local EtherTK   = require("EtherTK")

local OpenGL    = EtherTK.OpenGL

-- Shader 对象元表
local metatable_shader = 
{
    __index = 
    {
            -- 【内部调用】获取并缓存 Uniform 位置
        GetUniformLocation = function(self, name)
            local location = self.uniform_pool[name]
            if not location then
                location = OpenGL.GetUniformLocation(self.id, name)
                self.uniform_pool[name] = location
            end
            return location
        end,
        -- 使用当前 Shader
        Use = function(self)
            OpenGL.UseProgram(self.id)
        end,
        -- 设置 Uniform 值函数，下同
        Set1i = function(self, name, val)
            OpenGL.Uniform1i(self:GetUniformLocation(name), val)
        end,
        Set1f = function(self, name, val)
            OpenGL.Uniform1f(self:GetUniformLocation(name), val)
        end,
        Set2f = function(self, name, val_1, val_2)
            OpenGL.Uniform2f(self:GetUniformLocation(name), val_1, val_2)
        end,
        Set2fv = function(self, name, vec2)
            OpenGL.Uniform2fv(self:GetUniformLocation(name), vec2)
        end,
        Set3fv = function(self, name, vec3)
            OpenGL.Uniform3fv(self:GetUniformLocation(name), vec3)
        end,
        Set4f = function(self, name, val_1, val_2, val_3, val_4)
            OpenGL.Uniform4f(self:GetUniformLocation(name), val_1, val_2, val_3, val_4)
        end,
        Set4fv = function(self, name, vec4)
            OpenGL.Uniform4fv(self:GetUniformLocation(name), vec4)
        end,
        SetMat4fv = function(self, name, mat4)
            OpenGL.UniformMatrix4fv(self:GetUniformLocation(name), false, mat4)
        end,
    },
    __gc = function(self)
        OpenGL.DeleteProgram(self.id)
    end
}

__MODULE__.Create = function(vs, fs)

    local obj = {id = 0, uniform_pool = {}}

    local vertex_shader = OpenGL.CreateShader(OpenGL.VERTEX_SHADER)
    OpenGL.ShaderSource(vertex_shader, vs)
    OpenGL.CompileShader(vertex_shader)
    local status = OpenGL.GetShaderiv(vertex_shader, OpenGL.COMPILE_STATUS)
    if status == 0 then
        local err_msg = OpenGL.GetShaderInfoLog(vertex_shader)
        OpenGL.DeleteShader(vertex_shader)
        return false, string.format("[VERTEX SHADER]Error: %s", err_msg)
    end
    local fragment_shader = OpenGL.CreateShader(OpenGL.FRAGMENT_SHADER)
    OpenGL.ShaderSource(fragment_shader, fs)
    OpenGL.CompileShader(fragment_shader)
    status = OpenGL.GetShaderiv(fragment_shader, OpenGL.COMPILE_STATUS)
    if status == 0 then
        OpenGL.DeleteShader(vertex_shader)
        local err_msg = OpenGL.GetShaderInfoLog(fragment_shader)
        OpenGL.DeleteShader(fragment_shader)
        return false, string.format("[FRAGMENT SHADER]Error: %s", err_msg)
    end
    local program = OpenGL.CreateProgram()
    OpenGL.AttachShader(program, vertex_shader)
    OpenGL.AttachShader(program, fragment_shader)
    OpenGL.LinkProgram(program)
    status = OpenGL.GetProgramiv(program, OpenGL.LINK_STATUS)
    if status == 0 then
        OpenGL.DeleteShader(vertex_shader)
        OpenGL.DeleteShader(fragment_shader)
        local err_msg = OpenGL.GetProgramInfoLog(program)
        OpenGL.DeleteProgram(program)
        return false, string.format("[LINKING SHADER]Error: %s", err_msg) 
    end
    OpenGL.DeleteShader(vertex_shader)
    OpenGL.DeleteShader(fragment_shader)
    obj.id = program
    setmetatable(obj, metatable_shader)

    return true, obj

end

return __MODULE__