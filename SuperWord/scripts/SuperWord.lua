os.execute("chcp 65001")

local env_path = {"scripts\\?.lua", "scripts\\client\\?.lua"}
package.path = string.format("%s;%s", package.path, table.concat(env_path, ";"))

local EtherTK       = require("EtherTK")
local EasyGUI       = require("EasyGUI")

local Time      = EtherTK.Time
local ImGUI     = EtherTK.ImGUI
local Media     = EtherTK.Media
local Window    = EtherTK.Window
local String    = EtherTK.String
local Graphic   = EtherTK.Graphic

-- 窗口尺寸
local window_size               <const> = {x = 720 * 0.85, y = 1080 * 0.85}
-- 窗口背景颜色
local color_background          <const> = {r = 25, g = 25, b = 25, a = 255}
-- 帮助按钮图片纹理
local texture_button_help               = nil
-- 文本字体尺寸
local size_font                         = 30
-- 文本默认渲染颜色
local color_word_default        <const> = {r = 225, g = 225, b = 225, a = 255}
-- 强调文本渲染颜色
local color_word_highlight      <const> = {r = 226, g = 4, b = 27, a = 255}
-- 文本渲染目标纹理
local texture_target                    = nil
-- 文本渲染目标纹理尺寸
local texture_target_size               = {x = 0, y = 0}
-- 文本渲染目标纹理缓冲区背景颜色
local color_target_back         <const> = {r = 5, g = 5, b = 5, a = 255}
-- 文本字符间距
local word_spacing                      = {x = 5, y = 5}
-- 普通文本显示时间间隔
local interval_next_word                = 65
-- 普通文本淡出时间间隔
local interval_fadein_word              = 250
-- 强调文本显示时间间隔
local interval_next_highlight_word      = 240
-- 强调文本淡出时间间隔
local interval_fadein_highlight_word    = 50
-- 文本淡入偏移距离
local offset_fadein                     = {x = 15, y = 15}
-- 文本抖动最大偏移
local offset_shake                      = {x = 2, y = 2}
-- 文本抖动速度
local speed_shake                       = 0.5
-- 富文本输入框字符串缓冲
local cstring_richtext                  = String.CString("你认为这一切都是没有意义的吗？%你认为这仅仅是游戏便毫无价值吗？%\n你所做的一切可能#FFDB4FFF得不到任何感谢#，你所做的一切*在他人眼里可能只是伪善！*\n%即使如此你也愿意帮助他吗？%")
-- 红色按钮颜色样式
local color_button_red              <const> = ImGUI.HSVToRGB(0, 0.6, 0.6)
local color_button_red_active       <const> = ImGUI.HSVToRGB(0, 0.8, 0.8)
local color_button_red_hovered      <const> = ImGUI.HSVToRGB(0, 0.7, 0.7)
-- 绿色按钮颜色样式
local color_button_green            <const> = ImGUI.HSVToRGB(0.429, 0.6, 0.6)
local color_button_green_active     <const> = ImGUI.HSVToRGB(0.429, 0.8, 0.8)
local color_button_green_hovered    <const> = ImGUI.HSVToRGB(0.429, 0.7, 0.7)
-- 强调普通音效
local sound_normal_word                     = nil
-- 强调文本音效
local sound_highlight_word                  = nil
-- 渲染文本字体
local font_word                             = nil
-- 帮助信息窗口内容
local text_help_window              <const> = "% % 区间的文本将会随机抖动\n* * 区间内的文本将会被强调显示\n#FFFFFFFF # 区间内的文本将会被赋予指定颜色"
-- 文字信息列表
local word_list                             = {}
-- 文本显示时间间隔计时器
local timer_next_word                       = 0
-- 正在显示的文本索引
local idx_word_showing                      = 1

-- 将用 16 进制表示的颜色文本转换为 32 位颜色
local ConvertColor16ToColor8 = function(value_text)
    -- 将两位颜色分量文本转换为数字值
    local _ConvertTextToValue = function(text)
        -- 将 16 进制字符转换为 10 进制数字
        local _ConvertHexTextToDecNum = function(hex_text)
            local dec_num = tonumber(hex_text)
            if not dec_num then
                if hex_text == "A" then
                    dec_num = 10
                elseif hex_text == "B" then
                    dec_num = 11
                elseif hex_text == "C" then
                    dec_num = 12
                elseif hex_text == "D" then
                    dec_num = 13
                elseif hex_text == "E" then
                    dec_num = 14
                elseif hex_text == "F" then
                    dec_num = 15
                -- 对于不合法的十六进制字符，赋值为 0
                else
                    dec_num = 0
                end
            end
            return dec_num
        end

        local low = _ConvertHexTextToDecNum(string.sub(text, 2, 2))
        local high = _ConvertHexTextToDecNum(string.sub(text, 1, 1))
        return high * 16 + low
    end

    return 
    {
        r = _ConvertTextToValue(string.sub(value_text, 1, 2)),
        g = _ConvertTextToValue(string.sub(value_text, 3, 4)),
        b = _ConvertTextToValue(string.sub(value_text, 5, 6)),
        a = _ConvertTextToValue(string.sub(value_text, 7, 8))
    }
end

-- 重置 Super Word 演示
local ResetDisplay = function()
    word_list = {}
    timer_next_word = 0
    idx_word_showing = 1
end

-- 上次更新 Tick 的时间
local time_last_tick = nil
-- EasyGUI 帧更新回调
local OnTick = function()
    -- 计算得到帧间隔时间
    if not time_last_tick then
        time_last_tick = Time.GetInitTime()
    end
    local current_time = Time.GetInitTime()
    local delta_time = current_time - time_last_tick
    time_last_tick = current_time
    -- 开始渲染窗口 GUI 内容
    ImGUI.NewFrame()
    local viewport = ImGUI.GetMainViewport()
    local tmp_vec2_1, tmp_vec2_2 = {x = 0, y = 0}, {x = 0, y = 0}
    tmp_vec2_1.x, tmp_vec2_1.y = viewport:work_pos()
    ImGUI.SetNextWindowPos(tmp_vec2_1)
    tmp_vec2_2.x, tmp_vec2_2.y = viewport:work_size()
    ImGUI.SetNextWindowSize(tmp_vec2_2)
    ImGUI.Begin("MainPanel", nil, ImGUI.WINDOW_FLAGS_NO_DECORATION 
        | ImGUI.WINDOW_FLAGS_NO_MOVE | ImGUI.WINDOW_FLAGS_NO_RESIZE | ImGUI.WINDOW_FLAGS_NO_BACKGROUND)
    tmp_vec2_1.x = ImGUI.GetContentRegionAvail()
    tmp_vec2_1.y = window_size.y * 0.4
    ImGUI.BeginChild("RenderView", tmp_vec2_1, true)
    -- 如果文本渲染目标纹理为空则创建
    if not texture_target then
        local region_x, region_y = ImGUI.GetContentRegionAvail()
        texture_target = Graphic.CreateEmptyTexture(Graphic.PIXELFORMAT_RGBA32, Graphic.TEXTUREACCESS_TARGET, region_x, region_y)
        texture_target_size.x, texture_target_size.y = region_x, region_y
    end
    assert(texture_target, "创建文本渲染目标纹理失败！")

    -- 开始渲染文本渲染目标纹理的渲染缓冲内容
    Graphic.SetRenderTarget(texture_target)
    -- 更新文本显示推进计时器
    timer_next_word = timer_next_word + delta_time
    local word_next = word_list[idx_word_showing + 1]
    if word_next then
        local interval = interval_next_word
        if word_next.highlight then interval = interval_next_highlight_word end
        -- 如果计时器到达显示下一个字符的时间间隔则更新文本索引
        if timer_next_word >= interval then
            idx_word_showing = idx_word_showing + 1
            -- 重置计时器时间
            timer_next_word = 0
            -- 播放对应的音效
            if word_next.highlight then
                sound_highlight_word:play(0)
            else
                sound_normal_word:play(0)
            end
        end
    end
    for idx, word in ipairs(word_list) do
        -- 如果字符的当前渲染矩形信息不存在则新建
        if not word.current then
            word.current = 
            {
                x = word.rect.x + offset_fadein.x,
                y = word.rect.y + offset_fadein.y,
                w = word.rect.w, h = word.rect.h
            }
        end
        -- 如果字符的当前透明度信息不存在则新建
        if not word.alpha then
            word.alpha = 0
        end
        -- 如果当前字符在正在显示的文本索引前，则显示该字符
        if idx <= idx_word_showing then
            -- 更新字符透明度，实现淡出效果
            local speed_fadein = 255 / interval_fadein_word
            if word.highlight then speed_fadein = 255 / interval_fadein_highlight_word end
            word.alpha = word.alpha + speed_fadein * delta_time
            if word.alpha > 255 then word.alpha = 255 end
            word.texture:set_alpha(word.alpha)
            -- 如果尚未到达指定位置，则更新字符位置，实现滑入效果
            if not word.reach then
                local speed_x, speed_y = offset_fadein.x / interval_fadein_word, offset_fadein.y / interval_fadein_word
                if word.highlight then
                    speed_x, speed_y = offset_fadein.x / interval_fadein_highlight_word, offset_fadein.y / interval_fadein_highlight_word
                end
                word.current.x, word.current.y = word.current.x - speed_x * delta_time, word.current.y - speed_y * delta_time
                -- 如果字符到达指定位置，则设置已到达
                if word.current.x < word.rect.x or word.current.y < word.rect.y then
                    word.current.x, word.current.y = word.rect.x, word.rect.y
                    word.reach = true
                end
            -- 如果到达了指定位置，则开始抖动并更新抖动位置
            elseif word.shake then
                if not word.shaking then
                    if not word.shake_dst then
                        word.shake_dst = {x = 0, y = 0}
                    end
                    word.shaking = true
                    word.shake_dst.x = word.rect.x + math.random(-offset_shake.x, offset_shake.x)
                    word.shake_dst.y = word.rect.y + math.random(-offset_shake.y, offset_shake.y)
                else
                    local offset_x = word.shake_dst.x - word.current.x
                    local offset_y = word.shake_dst.y - word.current.y
                    local move_dis = delta_time * speed_shake
                    if move_dis >= math.abs(offset_x) then
                        word.current.x = word.shake_dst.x
                    end
                    if move_dis >= math.abs(offset_y) then
                        word.current.y = word.shake_dst.y
                    end
                    if word.current.x == word.shake_dst.x and word.current.y == word.shake_dst.y then
                        word.shaking = false
                    end
                end
            end
            Graphic.RenderTexture(word.texture, word.current)
        else
            break
        end
    end
    -- 重置当前渲染缓冲
    Graphic.SetRenderTarget()

    ImGUI.Image(texture_target, texture_target_size)
    ImGUI.EndChild()
    local _, x, y = ImGUI.InputInt2("文本字符间距（px）", word_spacing.x, word_spacing.y)
    word_spacing.x, word_spacing.y = x, y
    local _, interval = ImGUI.InputInt("普通文本显示时间间隔（ms）", interval_next_word)
    if interval >= 0 then interval_next_word = interval end
    _, interval = ImGUI.InputInt("普通文本淡出时间间隔（ms）", interval_fadein_word)
    if interval >= 0 then interval_fadein_word = interval end
    _, interval = ImGUI.InputInt("强调文本显示时间间隔（ms）", interval_next_highlight_word)
    if interval >= 0 then interval_next_highlight_word = interval end
    _, interval = ImGUI.InputInt("强调文本淡出时间间隔（ms）", interval_fadein_highlight_word)
    if interval >= 0 then interval_fadein_highlight_word = interval end
    _, x, y = ImGUI.InputInt2("文本淡入偏移距离（px）", offset_fadein.x, offset_fadein.y)
    if x >= 0 and y >= 0 then offset_fadein.x, offset_fadein.y = x, y end
    _, x, y = ImGUI.InputInt2("文本抖动最大偏移（px）", offset_shake.x, offset_shake.y)
    if x >= 0 and y >= 0 then offset_shake.x, offset_shake.y = x, y end
    local _, speed = ImGUI.InputNumber("文本抖动速度（px / s）", speed_shake)
    if speed >= 0 then speed_shake = speed end
    local region_x, region_y = ImGUI.GetContentRegionAvail()
    tmp_vec2_1.x, tmp_vec2_1.y = region_x, region_y - 28
    ImGUI.InputTextMultiline("##SuperWordText", cstring_richtext, tmp_vec2_1)
    local text_height = ImGUI.GetTextLineHeight()
    local item_spacing = ImGUI.GetStyle():item_spacing()
    tmp_vec2_1.x, tmp_vec2_1.y = region_x - text_height - item_spacing * 2, 0
    ImGUI.PushStyleColor(ImGUI.COLOR_BUTTON, color_button_red)
    ImGUI.PushStyleColor(ImGUI.COLOR_BUTTON_ACTIVE, color_button_red_active)
    ImGUI.PushStyleColor(ImGUI.COLOR_BUTTON_HOVERED, color_button_red_hovered)
    -- 点击生成演示按钮则解析文本框内容并开始演出
    if ImGUI.Button("生 成 演 示", tmp_vec2_1) then
        ResetDisplay()
        -- 开始解析文本框内容并生成指定样式的文本信息
        local text = cstring_richtext:get() 
        -- 当前文本渲染颜色
        local color_word = color_word_default
        -- 当前文本是否抖动，是否强调
        local is_shake, is_highlight = false, false
        -- 当前字符串渲染光标位置
        local cursor_word_pos = {x = 0, y = 0} 
        -- 当前扫描的文本索引和文本字符串总长度
        local idx_text, len_text = 1, String.UTF8Len(text)
        while idx_text <= len_text do
            -- 将渲染光标推进到下一行
            local _NextLine = function()
                cursor_word_pos.x = 0
                cursor_word_pos.y = cursor_word_pos.y + size_font + word_spacing.y
            end

            local word = String.UTF8Sub(text, idx_text, 1)
            -- 如果遇到换行符，则光标下移一行
            if word == "\n" then
                _NextLine()
            -- 遇到 % 开始切换抖动模式
            elseif word == "%" then
                is_shake = not is_shake
            -- 遇到 * 开始切换强调模式
            elseif word == "*" then
                is_highlight = not is_highlight
                if is_highlight then
                    color_word = color_word_highlight
                else
                    color_word = color_word_default
                end
            -- 遇到 # 开始切换变更颜色模式
            elseif word == "#" then
                -- 如果当前为默认颜色，则开始解析用户指定的颜色
                if color_word == color_word_default then
                    color_word = ConvertColor16ToColor8(String.UTF8Sub(text, idx_text + 1, 8))
                    idx_text = idx_text + 8
                -- 如果当前不为默认颜色，则恢复默认颜色
                else
                    color_word = color_word_default
                end
            -- 否则作为普通文本进行渲染
            else
                local word_info = 
                {
                    rect = 
                    {
                        x = cursor_word_pos.x,
                        y = cursor_word_pos.y,
                        w = 0, h = 0
                    }, 
                    texture = nil,
                    shake = is_shake,
                    highlight = is_highlight,
                }
                local imgae = Graphic.TextImageQuality(font_word, word, color_word) 
                    or Graphic.TextImageQuality(font_word, "?", color_word)
                word_info.texture = Graphic.CreateTexture(imgae)
                word_info.rect.w, word_info.rect.h = imgae:size()
                table.insert(word_list, word_info)
                cursor_word_pos.x = cursor_word_pos.x + word_info.rect.w + word_spacing.x
                -- 检查是否超出目标纹理边界，并换行显示
                if cursor_word_pos.x >= texture_target_size.x then
                    _NextLine()
                    word_info.rect.x, word_info.rect.y = cursor_word_pos.x, cursor_word_pos.y
                    cursor_word_pos.x = word_info.rect.w + word_spacing.x
                end
            end
            idx_text = idx_text + 1
        end
    end
    ImGUI.PopStyleColor(3)
    ImGUI.SameLine()
    ImGUI.PushStyleColor(ImGUI.COLOR_BUTTON, color_button_green)
    ImGUI.PushStyleColor(ImGUI.COLOR_BUTTON_ACTIVE, color_button_green_active)
    ImGUI.PushStyleColor(ImGUI.COLOR_BUTTON_HOVERED, color_button_green_hovered)
    tmp_vec2_1.x, tmp_vec2_1.y = text_height, text_height
    if ImGUI.ImageButton("HelpButton", texture_button_help, tmp_vec2_1) then
        Window.MessageBox(Window.MSGBOX_INFO, "帮助", text_help_window)
    end
    ImGUI.PopStyleColor(3)
    if ImGUI.IsItemHovered() then
        ImGUI.BeginTooltip()
        ImGUI.Text("显示帮助信息")
        ImGUI.EndTooltip()
    end
    ImGUI.End()
    ImGUI.RenderFrame()
end

-- EasyGUI 窗口清屏回调
local OnClear = function()
    -- 清空默认渲染缓冲
    Graphic.SetDrawColor(color_background)
    Window.Clear()
    -- 清空文本渲染目标纹理的渲染缓冲
    Graphic.SetRenderTarget(texture_target)
    Graphic.SetDrawColor(color_target_back)
    Window.Clear()
    -- 重置当前渲染目标为默认渲染缓冲
    Graphic.SetRenderTarget()
end

-- 程序主函数入口
local __MAIN__ = function()
    -- 初始化 EasyGUI 并注册相关函数
    EasyGUI.TickFunc(OnTick)    EasyGUI.ClearFunc(OnClear)
    EasyGUI.Init("SuperWord", window_size.x, window_size.y)
    ImGUI.GetStyle():frame_border_size(1.0)
    ImGUI.GetIO():add_font_from_ttf_file("C:\\Windows\\Fonts\\msyh.ttc", 18, ImGUI.FONT_GLYPH_RANGES_CHINESEFULL)
    texture_button_help = Graphic.CreateTexture(Graphic.ImageFile("resources\\help.png"))
    sound_normal_word = Media.SoundFile("resources\\du.mp3")
    sound_highlight_word = Media.SoundFile("resources\\kick.mp3")
    assert(sound_normal_word and sound_highlight_word, "音频文件加载失败")
    font_word = Graphic.FontFile("resources\\zpix.ttf", size_font)
    assert(font_word, "字体文件加载失败")
    Graphic.SetRenderMode(Graphic.RENDER_LINEAR)    
    -- 开启 EasyGUI 主循环
    EasyGUI.Mainloop()
end

local status, err_msg = pcall(__MAIN__)
if not status then
    Window.MessageBox(Window.MSGBOX_ERROR, "脚本崩溃", err_msg)
end