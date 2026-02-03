local fileName = ""

-- 全局设置
local boilSettings = {
    frameCount = 8.0,
    duration = 1.6,
    strength = 1.0,
    density = 2.0,
    perLayerSeed = false
}

function hash21(n)
    math.randomseed(n)
    return { math.random(), math.random() }
end

function hash22(p)
    math.randomseed(p[1] + p[2] * 7)
    return { math.random(), math.random() }
end

function perlin(px, py)
    local grid_x0 = math.floor(px)
    local grid_y0 = math.floor(py)
    local grid_x1 = grid_x0 + 1.0
    local grid_y1 = grid_y0 + 1.0

    local dir_x0 = px - grid_x0
    local dir_y0 = py - grid_y0
    local dir_x1 = dir_x0 - 1.0
    local dir_y1 = dir_y0 - 1.0

    local dir_x0_2 = dir_x0 * dir_x0
    local dir_x0_3 = dir_x0_2 * dir_x0
    local dir_y0_2 = dir_y0 * dir_y0
    local dir_y0_3 = dir_y0_2 * dir_y0

    local t_0 = dir_x0_3 * (6.0 * dir_x0_2 - 15.0 * dir_x0 + 10.0)
    local t_1 = dir_y0_3 * (6.0 * dir_y0_2 - 15.0 * dir_y0 + 10.0)

    local g00 = hash22({ grid_x0, grid_y0 })
    local g01 = hash22({ grid_x0, grid_y1 })
    local g10 = hash22({ grid_x1, grid_y0 })
    local g11 = hash22({ grid_x1, grid_y1 })

    local p00 = (g00[1] * 2.0 - 1.0) * dir_x0 + (g00[2] * 2.0 - 1.0) * dir_y0
    local p01 = (g01[1] * 2.0 - 1.0) * dir_x0 + (g01[2] * 2.0 - 1.0) * dir_y1
    local p10 = (g10[1] * 2.0 - 1.0) * dir_x1 + (g10[2] * 2.0 - 1.0) * dir_y0
    local p11 = (g11[1] * 2.0 - 1.0) * dir_x1 + (g11[2] * 2.0 - 1.0) * dir_y1

    local mix_0 = p00 + (p10 - p00) * t_0
    local mix_1 = p01 + (p11 - p01) * t_0
    return mix_0 + (mix_1 - mix_0) * t_1
end

function createBoilImage(originalImage, boilStrength, boilDensity, seed, frameIndex, offsetX, offsetY, canvasWidth,
                         canvasHeight)
    local strengthCeil = math.ceil(boilStrength)
    local width = originalImage.width + 2 * strengthCeil
    local height = originalImage.height + 2 * strengthCeil
    seed = seed or 0.0
    frameIndex = frameIndex or 0

    local newImage = Image(width, height)
    newImage:clear(0)

    local sp = hash21(frameIndex + seed)
    local sp_x = sp[1] * 1024.0
    local sp_y = sp[2] * 1024.0
    local boilDensity_w = boilDensity / canvasWidth
    local boilDensity_h = boilDensity / canvasHeight
    local boilStrength_4pi = boilStrength * 4.0 * math.pi

    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local uvX = x - strengthCeil
            local uvY = y - strengthCeil

            local noise_coord_x = boilDensity_w * (uvX + offsetX + sp_x)
            local noise_coord_y = boilDensity_h * (uvY + offsetY + sp_y)
            local noise = perlin(noise_coord_x, noise_coord_y) * boilStrength_4pi

            local uvBiasX = math.cos(noise) * boilStrength
            local uvBiasY = math.sin(noise) * boilStrength

            local srcX = uvX + math.floor(uvBiasX + 0.5)
            local srcY = uvY + math.floor(uvBiasY + 0.5)

            local color
            if srcX >= 0 and srcX < originalImage.width and srcY >= 0 and srcY < originalImage.height then
                color = originalImage:getPixel(srcX, srcY)
            elseif uvX >= 0 and uvX < originalImage.width and uvY >= 0 and uvY < originalImage.height then
                color = originalImage:getPixel(uvX, uvY)
            else
                color = Color { r = 0, g = 0, b = 0, a = 0 }
            end

            -- color = Color { r = (uvX - srcX) * 128 + 128, g = (uvY - srcY) * 128 + 128, b = 0, a = 255 }

            newImage:drawPixel(x, y, color)
        end
    end

    return newImage
end

function applyBoilEffect(boilFrameCount, boilDuration, boilStrength, boilDensity, perLayerSeed)
    local sprite = app.activeSprite

    if not sprite then
        return
    end

    local durationPerFrame = boilDuration / boilFrameCount
    local currentFrame = app.activeFrame
    local currentFrameIndex = app.activeFrame.frameNumber
    local insertFrameIndex = currentFrameIndex + 1

    local originalCels = {}
    local visibleCelCount = 0
    for i, layer in ipairs(sprite.layers) do
        if layer.isVisible then
            local originalCel = layer:cel(currentFrameIndex)
            if originalCel and originalCel.image then
                originalCels[i] = { Point(originalCel.position.x, originalCel.position.y), originalCel.image }
                visibleCelCount = visibleCelCount + 1
            end
        end
    end

    app.transaction("Create Boil Effect", function()
        local baseSeed = os.time()

        for i = 1, boilFrameCount do
            local newFrame = sprite:newFrame(currentFrameIndex)
            newFrame = sprite.frames[insertFrameIndex]
            newFrame.duration = durationPerFrame

            for j, layer in ipairs(sprite.layers) do
                if not layer.isVisible then
                    goto continue
                end

                local originalCel = originalCels[j]
                if not originalCel then
                    goto continue
                end
                local newCel = layer:cel(insertFrameIndex)

                if not newCel then
                    newCel = layer:newCel(insertFrameIndex)
                end

                local layerSeed = baseSeed
                if perLayerSeed then
                    layerSeed = baseSeed + j
                end

                newCel.image = createBoilImage(originalCel[2], boilStrength, boilDensity, layerSeed, i,
                    originalCel[1].x, originalCel[1].y, app.activeSprite.width, app.activeSprite.height)
                newCel.position = Point(originalCel[1].x - boilStrength, originalCel[1].y - boilStrength)

                ::continue::
            end
        end

        local tag = sprite:newTag(insertFrameIndex, insertFrameIndex + boilFrameCount - 1)
        tag.name = "Boil Effect"
    end)
end

function init(plugin)
    plugin:newCommand {
        id = "create_boil_effect",
        title = "Create Boil Effect",
        group = "edit_fx",
        onclick = function()
            local dlg = Dialog("Boil Effect Settings")

            dlg:number {
                id = "frameCount",
                label = "Frame Count:",
                text = tostring(boilSettings.frameCount)
            }
            dlg:number {
                id = "duration",
                label = "Duration (seconds):",
                text = tostring(boilSettings.duration),
                decimals = 1
            }
            dlg:number {
                id = "strength",
                label = "Strength:",
                text = tostring(boilSettings.strength),
                decimals = 1
            }
            dlg:number {
                id = "density",
                label = "Density:",
                text = tostring(boilSettings.density),
                decimals = 1
            }
            dlg:check {
                id = "perLayerSeed",
                label = "Per Layer Seed:",
                selected = boilSettings.perLayerSeed
            }

            dlg:button { id = "ok", text = "OK" }
            dlg:button { id = "cancel", text = "Cancel" }

            dlg:show()

            if dlg.data.ok then
                boilSettings.frameCount = tonumber(dlg.data.frameCount) or 8
                boilSettings.duration = tonumber(dlg.data.duration) or 2
                boilSettings.strength = tonumber(dlg.data.strength) or 2
                boilSettings.density = tonumber(dlg.data.density) or 2
                boilSettings.perLayerSeed = dlg.data.perLayerSeed

                applyBoilEffect(
                    boilSettings.frameCount,
                    boilSettings.duration,
                    boilSettings.strength,
                    boilSettings.density,
                    boilSettings.perLayerSeed
                )
            end
        end,
    }
end

function exit(plugin)

end
