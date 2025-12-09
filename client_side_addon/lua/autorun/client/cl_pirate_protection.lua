--[[
    ПИРАТСКАЯ ЗАЩИТА - КЛИЕНТСКАЯ ЧАСТЬ
    Эксклюзивно для сервера: 26.211.58.48:27015
]]

-- Конфигурация
local SERVER_IP = "26.211.58.48"
local SERVER_PORT = 27015
local ADDON_VERSION = "1.0.0"
local ADDON_KEY = "PIRATE_PROTECT_2024_KEY"

-- Проверка подключения к правильному серверу
local function IsCorrectServer()
    if not IsValid(LocalPlayer()) then return false end
    
    -- Проверяем через GetHostName и другие методы
    local hostname = GetHostName()
    if hostname and hostname ~= "" then
        -- Можно добавить проверку по hostname если нужно
    end
    
    -- Основная проверка будет через сравнение IP при подключении
    -- Для упрощения проверяем только при подключении через команду connect
    return true -- Разрешаем работу, проверка будет на сервере
end

-- Показ сообщения об эксклюзивности
local function ShowExclusiveMessage()
    chat.AddText(Color(255, 0, 0), "[Защита] ", Color(255, 255, 255), "Этот аддон создан для сервера " .. SERVER_IP .. ":" .. SERVER_PORT)
    notification.AddLegacy("Этот аддон создан для сервера " .. SERVER_IP .. ":" .. SERVER_PORT, NOTIFY_ERROR, 5)
end

-- Переменные состояния
local isPirate = false
local downloadInProgress = false
local filesToDownload = {}
local downloadProgress = 0
local downloadTotal = 0

-- Определение пирата
local function CheckIfPirate()
    local steamID = LocalPlayer():SteamID()
    local steamID64 = LocalPlayer():SteamID64()
    
    -- Проверка на пиратство
    if steamID == "STEAM_ID_PENDING" then
        return true
    end
    
    if steamID:match("^STEAM_0:0:0") or steamID:match("^STEAM_0:1:0") then
        return true
    end
    
    if not steamID64 or steamID64 == "0" or steamID64 == "" then
        return true
    end
    
    -- Проверка валидности SteamID64 (должен быть числом больше 76561197960265728)
    local id64 = tonumber(steamID64)
    if not id64 or id64 < 76561197960265728 then
        return true
    end
    
    return false
end

-- Сетевые сообщения
if SERVER then return end

-- Регистрация сетевых сообщений (получение от сервера)
net.Receive("PirateProtection_FilesList", function()
    local workshopID = net.ReadString()
    local fileCount = net.ReadUInt(16)
    
    filesToDownload = {}
    for i = 1, fileCount do
        local fileName = net.ReadString()
        local fileURL = net.ReadString()
        table.insert(filesToDownload, {
            name = fileName,
            url = fileURL
        })
    end
    
    downloadTotal = #filesToDownload
    downloadProgress = 0
    
    if downloadTotal > 0 then
        ShowDownloadWindow()
        DownloadNextFile()
    else
        -- Нет файлов для загрузки, можно подключаться
        ConnectToServer()
    end
end)


-- Окно загрузки
local downloadFrame = nil
local function ShowDownloadWindow()
    if IsValid(downloadFrame) then downloadFrame:Remove() end
    
    downloadFrame = vgui.Create("DFrame")
    downloadFrame:SetSize(500, 200)
    downloadFrame:Center()
    downloadFrame:SetTitle("Загрузка контента сервера")
    downloadFrame:SetDraggable(false)
    downloadFrame:ShowCloseButton(false)
    downloadFrame:MakePopup()
    
    local label = vgui.Create("DLabel", downloadFrame)
    label:SetPos(20, 40)
    label:SetSize(460, 30)
    label:SetText("Загрузка необходимых файлов...")
    label:SetFont("DermaDefault")
    
    local progressBar = vgui.Create("DProgress", downloadFrame)
    progressBar:SetPos(20, 80)
    progressBar:SetSize(460, 30)
    progressBar:SetFraction(0)
    
    local statusLabel = vgui.Create("DLabel", downloadFrame)
    statusLabel:SetPos(20, 120)
    statusLabel:SetSize(460, 30)
    statusLabel:SetText("Ожидание...")
    statusLabel:SetFont("DermaDefault")
    
    downloadFrame.progressBar = progressBar
    downloadFrame.statusLabel = statusLabel
end

-- Обновление прогресса загрузки
local function UpdateDownloadProgress(current, total, fileName)
    if not IsValid(downloadFrame) then return end
    
    local fraction = total > 0 and (current / total) or 0
    downloadFrame.progressBar:SetFraction(fraction)
    downloadFrame.statusLabel:SetText(string.format("Загрузка: %d/%d - %s", current, total, fileName or ""))
end

-- Загрузка файла
local function DownloadNextFile()
    if downloadProgress >= downloadTotal then
        -- Все файлы загружены
        if IsValid(downloadFrame) then
            downloadFrame.statusLabel:SetText("Загрузка завершена. Перезагрузка контента...")
        end
        
        timer.Simple(2, function()
            if IsValid(downloadFrame) then
                downloadFrame:Remove()
            end
            ConnectToServer()
        end)
        return
    end
    
    local fileInfo = filesToDownload[downloadProgress + 1]
    if not fileInfo then
        DownloadNextFile()
        return
    end
    
    UpdateDownloadProgress(downloadProgress, downloadTotal, fileInfo.name)
    
    -- Загрузка файла
    http.Fetch(fileInfo.url, function(body, len, headers, code)
        if code ~= 200 then
            Error("Ошибка загрузки файла " .. fileInfo.name .. ": HTTP " .. code)
            -- Продолжаем со следующим файлом
            downloadProgress = downloadProgress + 1
            DownloadNextFile()
            return
        end
        
        -- Сохранение файла
        local addonPath = "garrysmod/addons/" .. fileInfo.name .. "/"
        file.CreateDir(addonPath)
        
        -- Распаковка ZIP архива
        if fileInfo.url:match("%.zip$") then
            -- Здесь нужна библиотека для распаковки ZIP
            -- Для упрощения сохраняем как есть и просим игрока распаковать вручную
            file.Write(addonPath .. fileInfo.name .. ".zip", body)
            
            -- Показываем инструкцию
            if IsValid(downloadFrame) then
                downloadFrame.statusLabel:SetText("Файл сохранён. Распакуйте " .. fileInfo.name .. ".zip в папку addons/")
            end
            
            timer.Simple(3, function()
                downloadProgress = downloadProgress + 1
                DownloadNextFile()
            end)
        else
            -- Обычный файл
            file.Write(addonPath .. fileInfo.name, body)
            downloadProgress = downloadProgress + 1
            DownloadNextFile()
        end
    end, function(error)
        Error("Ошибка загрузки файла " .. fileInfo.name .. ": " .. error)
        
        -- Показываем альтернативный способ
        if IsValid(downloadFrame) then
            local altFrame = vgui.Create("DFrame")
            altFrame:SetSize(600, 200)
            altFrame:Center()
            altFrame:SetTitle("Ошибка загрузки")
            altFrame:MakePopup()
            
            local label = vgui.Create("DLabel", altFrame)
            label:SetPos(20, 40)
            label:SetSize(560, 100)
            label:SetText("Не удалось загрузить файл автоматически.\n\nСкачайте вручную по ссылке:\n" .. fileInfo.url .. "\n\nИ поместите в папку garrysmod/addons/")
            label:SetWrap(true)
            
            local btn = vgui.Create("DButton", altFrame)
            btn:SetPos(250, 150)
            btn:SetSize(100, 30)
            btn:SetText("Продолжить")
            btn.DoClick = function()
                altFrame:Remove()
                downloadProgress = downloadProgress + 1
                DownloadNextFile()
            end
        else
            downloadProgress = downloadProgress + 1
            DownloadNextFile()
        end
    end)
end

-- Подключение к серверу
local function ConnectToServer()
    RunConsoleCommand("disconnect")
    timer.Simple(1, function()
        RunConsoleCommand("connect", SERVER_IP .. ":" .. SERVER_PORT)
    end)
end

-- Проверка при подключении
hook.Add("PlayerInitialSpawn", "PirateProtection_Check", function(ply)
    if ply ~= LocalPlayer() then return end
    
    -- Отправляем инициализацию на сервер
    timer.Simple(1, function()
        if not IsValid(LocalPlayer()) then return end
        
        isPirate = CheckIfPirate()
        
        -- Отправляем инициализацию
        net.Start("PirateProtection_Init")
        net.WriteString(ADDON_KEY)
        net.WriteString(ADDON_VERSION)
        net.SendToServer()
        
        -- Если пират, запрашиваем файлы
        if isPirate then
            timer.Simple(0.5, function()
                net.Start("PirateProtection_RequestFiles")
                net.WriteString(ADDON_KEY)
                net.WriteString(ADDON_VERSION)
                net.SendToServer()
            end)
        end
    end)
end)

-- Проверка при попытке подключения к другому серверу
hook.Add("StartCommand", "PirateProtection_ServerCheck", function(cmd)
    if cmd:GetCommand() == "connect" then
        local args = cmd:GetArguments()
        if args and args[1] then
            local targetIP, targetPort = args[1]:match("([^:]+):?(%d*)")
            if targetIP and targetIP ~= SERVER_IP then
                timer.Simple(0.1, function()
                    ShowExclusiveMessage()
                end)
            end
        end
    end
end)

