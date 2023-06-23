--[=======================================================================[

    Glut 怀旧风格的、初生就能学会用的简易程序框架，爱来自 EtherTK；
    本框架默认初始化 ImGUI，但是你完全可以用来做其他窗口化的普适性应用；

    1. 你首先需要通过调用 Init 函数初始化本框架，参数列表如下：

    title:  <string>    窗口标题
    width:  <number>    窗口宽度
    height: <number>    窗口高度
    flags:  <enum>      窗口标志，默认为 Window.SHOWN
    fps:    <number>    窗口帧率，默认为 60

    2. 注册各类事件回调，你可能需要注册的回调函数的 API 有如下几个：

    +——— 函数名 ———+—————— 功能 ——————+—————— 参数 ——————+——— 返回值 ———+
    |  ClearFunc   |   注册清屏回调   |        无        |              |
    |   TickFunc   |  注册帧更新回调  |        无        |              |
    |  CloseFunc   | 注册窗口退出回调 |        无        |    是否退出   |
    |  WindowFunc  | 注册窗口事件回调 |   窗口事件类型    |              |
    |  MouseFunc   | 注册鼠标事件回调 |   鼠标事件类型    |              |
    | KeyboardFunc | 注册键盘事件回调 |   键盘事件类型    |              |
    +——————————————+—————————————————+——————————————————+——————————————+

    3. 调用 Mainloop 函数执行本框架的主循环，至此，万事大吉！

    4. 如果你希望在程序运行时主动退出，可以调用 Quit 函数，
        此函数会调用 CloseFunc 注册的回调来决定是否真正退出程序。

--]=======================================================================]

local __MODULE__ = {}

local EtherTK   = require("EtherTK")

local Time      = EtherTK.Time
local Input     = EtherTK.Input
local ImGUI     = EtherTK.ImGUI
local Window    = EtherTK.Window

local EMPTY_FUNC <const> = function() return true end

local cb_clear      = EMPTY_FUNC    -- 窗口清屏回调
local cb_tick       = EMPTY_FUNC    -- 帧更新回调
local cb_close      = EMPTY_FUNC    -- 窗口关闭回调
local cb_window     = EMPTY_FUNC    -- 窗口事件回调
local cb_mouse      = EMPTY_FUNC    -- 鼠标事件回调
local cb_keyboard   = EMPTY_FUNC    -- 键盘事件回调
local cb_input      = EMPTY_FUNC    -- 文本输入回调
local cb_drop       = EMPTY_FUNC    -- 拖放文件回调

local g_fps   = 0   -- 帧率
local quit  = false -- 是否退出

local event_handler_pool = 
{
    [Input.EVENT_QUIT]          = function() quit = cb_close() end,
    [Input.EVENT_MOUSEMOTION]   = function() cb_mouse(Input.EVENT_MOUSEMOTION) end,
    [Input.EVENT_MOUSEWHEEL]    = function() cb_mouse(Input.EVENT_MOUSEWHEEL) end,
    [Input.EVENT_TEXTINPUT]     = function() cb_input() end,
    [Input.EVENT_KEYDOWN]       = function() cb_keyboard(Input.EVENT_KEYDOWN) end,
    [Input.EVENT_KEYUP]         = function() cb_keyboard(Input.EVENT_KEYUP) end,
    [Input.EVENT_DROPFILE]      = function() cb_drop(Input.EVENT_DROPFILE) end,
    [Input.EVENT_DROPBEGIN]     = function() cb_drop(Input.EVENT_DROPBEGIN) end,
    [Input.EVENT_DROPCOMPLETE]  = function() cb_drop(Input.EVENT_DROPCOMPLETE) end,
    [Input.EVENT_WINDOW]        = function() cb_window() end,
    [Input.EVENT_MOUSEBTNDOWN]  = function() cb_mouse(Input.EVENT_MOUSEBTNDOWN) end,
    [Input.EVENT_MOUSEBTNUP]    = function() cb_mouse(Input.EVENT_MOUSEBTNUP) end,
}

__MODULE__.Init = function(title, width, height, flags, fps)
    flags = flags or Window.SHOWN
    Window.Create(title, {
        x = Window.CENTER_POSITION, 
        y = Window.CENTER_POSITION, 
        w = width, h = height
    }, flags)
    g_fps = fps or 60
    ImGUI.Init()
end

__MODULE__.Quit = function()
    event_handler_pool[Input.EVENT_QUIT]()
end

__MODULE__.ClearFunc = function(callback)
    assert(type(callback) == "function")
    cb_clear = callback
end

__MODULE__.TickFunc = function(callback)
    assert(type(callback) == "function")
    cb_tick = callback
end

__MODULE__.CloseFunc = function(callback)
    assert(type(callback) == "function")
    cb_close = callback
end

__MODULE__.WindowFunc = function(callback)
    assert(type(callback) == "function")
    cb_window = callback
end

__MODULE__.MouseFunc = function(callback)
    assert(type(callback) == "function")
    cb_mouse = callback
end

__MODULE__.KeyboardFunc = function(callback)
    assert(type(callback) == "function")
    cb_keyboard = callback
end

__MODULE__.Mainloop = function(callback)
    local spf <const> = 1000 / g_fps
    while not quit do
        local begin_frame = Time.GetInitTime()
        while Input.UpdateEvent() do
            ImGUI.ProcessEvent()
            local event = Input.GetEventType()
            local handler = event_handler_pool[event]
            if handler then handler() end
        end
        cb_clear() cb_tick() Window.Update()
        local end_frame = Time.GetInitTime()
        local delay = end_frame - begin_frame
        if spf > delay then Time.Sleep(spf - delay) end
    end
    ImGUI.Quit()
    Window.Close()
end

return __MODULE__