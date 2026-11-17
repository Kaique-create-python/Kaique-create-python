-- Canonical import contract for the genuine skinned monster. No uploads.
-- Call Prepare once on the static import, before playing any animation.
-- A returned report is an import check, not proof of visible skin deformation.
local Contract = {}
Contract.HeightStuds = 9.091193199157715
Contract.MeshName = "Monster_Animated_18k"
Contract.VisualFacingYawDegrees = 180
Contract.SourceBoundsCenter = Vector3.new(0.00188708305359, 4.5462965965271, -0.00235641002655)
-- Tamanho da malha no arquivo (X, Y, Z), para conferir a malha depois de um giro do importador.
Contract.SourceBoundsSize = Vector3.new(4.24777738976, 9.09119329982, 2.08837299636)
Contract.RootBone = "pelvis"
-- Tolerâncias: ossos filhos (pose relativa, que as animações usam) e a raiz (giro do modelo inteiro).
Contract.MaxRestPositionStuds = 0.02
Contract.MaxRestAngleRadians = 0.003
-- A raiz pode mudar de referência (centro da malha) sem deformar nada: só um limite de sanidade.
Contract.MaxRootOffsetStuds = 0.5
-- Inclinação do monstro em pé no mundo (MeshPart + raiz juntas): precisa ser ~0.
Contract.MaxRootTiltRadians = 0.003
Contract.MaxMeshSizeErrorStuds = 0.25
local expected = {
    ["pelvis"] = { parent = "Monster_Animated_18k", rest = CFrame.new(0, 4.33333281315, 0.181818177754, 1, -0, 0, 0, 0.999056158931, 0.0434372110404, -0, -0.0434372110404, 0.999056158931) },
    ["spine_01"] = { parent = "pelvis", rest = CFrame.new(0, 0.697628340938, 1.12887584802e-08, 1, 0, 0, 0, 0.997876108106, -0.0651404088978, 0, 0.0651404088978, 0.997876108106) },
    ["spine_02"] = { parent = "spine_01", rest = CFrame.new(0, 0.697134299712, 8.46656886014e-09, 1, -0, 0, 0, 0.999763789022, 0.0217339863092, -0, -0.0217339863092, 0.999763789022) },
    ["chest"] = { parent = "spine_02", rest = CFrame.new(0, 0.727273839893, 0, 1, -0, 0, 0, 0.991600400194, 0.129339268344, -0, -0.129339268344, 0.991600400194) },
    ["neck"] = { parent = "chest", rest = CFrame.new(0, 0.702873007818, 5.64437924009e-08, 1, 0, 0, 0, 0.973809552632, -0.227365246251, 0, 0.227365246251, 0.973809552632) },
    ["head"] = { parent = "neck", rest = CFrame.new(0, 0.456812842326, 1.12887584802e-08, 1, 0, 0, 0, 0.993624955804, -0.11273618409, 0, 0.11273618409, 0.993624955804) },
    ["clavicle.L"] = { parent = "chest", rest = CFrame.new(0.181818177754, 0.642776353793, -0.00783867682471, 0.26300594272, 0.963658787292, 0.0467933303885, -0.0782387677517, -0.0270380676788, 0.996567929505, 0.961616643634, -0.265764340292, 0.0682843035716) },
    ["upper_arm.L"] = { parent = "clavicle.L", rest = CFrame.new(0, 0.990542950052, -7.26713827162e-07, 0.508098169069, -0.0861087998147, -0.856983970202, 0.823838903441, 0.338835077642, 0.454400980783, 0.251248306991, -0.936897040637, 0.243101261782) },
    ["forearm.L"] = { parent = "upper_arm.L", rest = CFrame.new(2.25775169604e-07, 1.86455990329, 1.35465101762e-07, 0.985603282018, -0.0776188623585, -0.150204802458, 0.112042517479, 0.96516440508, 0.236440574868, 0.126620080368, -0.249865930797, 0.959965818076) },
    ["hand.L"] = { parent = "forearm.L", rest = CFrame.new(6.49103612611e-08, 1.93532687245, -4.51550339208e-08, 0.974856608848, -0.160059555533, -0.155033966819, 0.148169710237, 0.985258835581, -0.0855030050805, 0.166434158613, 0.0603818316386, 0.984202065256) },
    ["thumb_01.L"] = { parent = "hand.L", rest = CFrame.new(-0.214489278468, 0.270749583389, -0.234668092294, -0.0379534558913, -0.835018601241, 0.548911168376, -0.350238807169, 0.525577914013, 0.775306800083, -0.935891186591, -0.162824420415, -0.31240341704) },
    ["thumb_02.L"] = { parent = "thumb_01.L", rest = CFrame.new(4.02330720927e-08, 0.165033408187, -6.77325508811e-08, 0.831697673451, -0.423861693702, -0.358636647023, 0.297232392193, 0.885468221791, -0.357209928794, 0.468968959534, 0.190492238189, 0.862427285157) },
    ["thumb_03.L"] = { parent = "thumb_02.L", rest = CFrame.new(-5.15220566547e-08, 0.178273913987, 2.30714001439e-07, 0.913704730241, -0.378925349621, -0.146830668971, 0.310229480471, 0.883782926067, -0.350264769907, 0.262490638657, 0.274487374949, 0.925070454404) },
    ["index_01.L"] = { parent = "hand.L", rest = CFrame.new(-0.122462980675, 0.569711625576, -0.286311091799, -0.0282717325686, -0.215214585495, 0.976157462363, 0.0490528822355, 0.975072586748, 0.216396084338, -0.998395975494, 0.0540012292699, -0.0170100956899) },
    ["index_02.L"] = { parent = "index_01.L", rest = CFrame.new(-2.8151360031e-09, 0.309477565867, -1.01334246045e-07, 0.983958775846, -0.170475002405, -0.0525680605631, 0.172968439875, 0.983795730062, 0.0472004271087, 0.0436697405947, -0.0555358899001, 0.997501237438) },
    ["index_03.L"] = { parent = "index_02.L", rest = CFrame.new(-8.44408987177e-09, 0.287942768949, 3.66884650606e-08, 0.920194104537, -0.340662661362, -0.192851655758, 0.374080925527, 0.910393694024, 0.176767596122, 0.115352811547, -0.2348026257, 0.965174313703) },
    ["middle_01.L"] = { parent = "hand.L", rest = CFrame.new(0.0997668527292, 0.556235421788, -0.0413982649193, -0.0279454724467, -0.191062710569, 0.981179948429, 0.0597510955341, 0.979488894306, 0.192435216409, -0.997822056858, 0.0640042698727, -0.0159560736354) },
    ["middle_02.L"] = { parent = "middle_01.L", rest = CFrame.new(1.10728396149e-08, 0.301541817008, -2.62816408367e-08, 0.985517180019, -0.163297652837, -0.0457139416931, 0.165379416838, 0.985147265795, 0.0462007920146, 0.0374904837725, -0.0530918192795, 0.997885625887) },
    ["middle_03.L"] = { parent = "middle_02.L", rest = CFrame.new(3.99848020014e-08, 0.31474338788, 8.04324041713e-08, 0.984623264843, -0.15662513641, -0.0773666140758, 0.16822379038, 0.969503997736, 0.178221083835, 0.0470933400711, -0.188495530498, 0.980944265646) },
    ["ring_01.L"] = { parent = "hand.L", rest = CFrame.new(0.141735047554, 0.546609768362, 0.257361070676, -0.0282588842526, -0.310548656546, 0.950137341324, 0.0494685085127, 0.948917807182, 0.311621343748, -0.998375832102, 0.0558079486411, -0.0114529796185) },
    ["ring_02.L"] = { parent = "ring_01.L", rest = CFrame.new(1.25023224097e-09, 0.312547205072, -6.70270034761e-09, 0.987761766828, -0.138706964749, -0.0713236981901, 0.146715367068, 0.981488008974, 0.123109257596, 0.0529272430756, -0.132066900356, 0.989826773113) },
    ["ring_03.L"] = { parent = "ring_02.L", rest = CFrame.new(9.07618223003e-09, 0.231932148789, -2.82218962005e-08, 0.98561242526, -0.129398948958, -0.108738489883, 0.150313421328, 0.965241051532, 0.213812038498, 0.0772918012604, -0.227080656258, 0.970803972495) },
    ["clavicle.R"] = { parent = "chest", rest = CFrame.new(-0.181818177754, 0.642776353793, -0.00783867682471, 0.26300594272, -0.963658787292, -0.0467933303885, 0.0782387677517, -0.0270380676788, 0.996567929505, -0.961616643634, -0.265764340292, 0.0682843035716) },
    ["upper_arm.R"] = { parent = "clavicle.R", rest = CFrame.new(0, 0.990542950052, -7.26713827162e-07, 0.508098169069, 0.0861087998147, 0.856983970202, -0.823838903441, 0.338835077642, 0.454400980783, -0.251248306991, -0.936897040637, 0.243101261782) },
    ["forearm.R"] = { parent = "upper_arm.R", rest = CFrame.new(-2.25775169604e-07, 1.86455990329, 1.35465101762e-07, 0.985603282018, 0.0776188623585, 0.150204802458, -0.112042517479, 0.96516440508, 0.236440574868, -0.126620080368, -0.249865930797, 0.959965818076) },
    ["hand.R"] = { parent = "forearm.R", rest = CFrame.new(-6.49103612611e-08, 1.93532687245, -4.51550339208e-08, 0.974856608848, 0.160059555533, 0.155033966819, -0.148169710237, 0.985258835581, -0.0855030050805, -0.166434158613, 0.0603818316386, 0.984202065256) },
    ["thumb_01.R"] = { parent = "hand.R", rest = CFrame.new(0.214489278468, 0.270749583389, -0.234668092294, -0.0379534558913, 0.835018601241, -0.548911168376, 0.350238807169, 0.525577914013, 0.775306800083, 0.935891186591, -0.162824420415, -0.31240341704) },
    ["thumb_02.R"] = { parent = "thumb_01.R", rest = CFrame.new(-4.02330720927e-08, 0.165033408187, -6.77325508811e-08, 0.831697673451, 0.423861693702, 0.358636647023, -0.297232392193, 0.885468221791, -0.357209928794, -0.468968959534, 0.190492238189, 0.862427285157) },
    ["thumb_03.R"] = { parent = "thumb_02.R", rest = CFrame.new(5.15220566547e-08, 0.178273913987, 2.30714001439e-07, 0.913704730241, 0.378925349621, 0.146830668971, -0.310229480471, 0.883782926067, -0.350264769907, -0.262490638657, 0.274487374949, 0.925070454404) },
    ["index_01.R"] = { parent = "hand.R", rest = CFrame.new(0.122462980675, 0.569711625576, -0.286311091799, -0.0282717325686, 0.215214585495, -0.976157462363, -0.0490528822355, 0.975072586748, 0.216396084338, 0.998395975494, 0.0540012292699, -0.0170100956899) },
    ["index_02.R"] = { parent = "index_01.R", rest = CFrame.new(2.8151360031e-09, 0.309477565867, -1.01334246045e-07, 0.983958775846, 0.170475002405, 0.0525680605631, -0.172968439875, 0.983795730062, 0.0472004271087, -0.0436697405947, -0.0555358899001, 0.997501237438) },
    ["index_03.R"] = { parent = "index_02.R", rest = CFrame.new(8.44408987177e-09, 0.287942768949, 3.66884650606e-08, 0.920194104537, 0.340662661362, 0.192851655758, -0.374080925527, 0.910393694024, 0.176767596122, -0.115352811547, -0.2348026257, 0.965174313703) },
    ["middle_01.R"] = { parent = "hand.R", rest = CFrame.new(-0.0997668527292, 0.556235421788, -0.0413982649193, -0.0279454724467, 0.191062710569, -0.981179948429, -0.0597510955341, 0.979488894306, 0.192435216409, 0.997822056858, 0.0640042698727, -0.0159560736354) },
    ["middle_02.R"] = { parent = "middle_01.R", rest = CFrame.new(-1.10728396149e-08, 0.301541817008, -2.62816408367e-08, 0.985517180019, 0.163297652837, 0.0457139416931, -0.165379416838, 0.985147265795, 0.0462007920146, -0.0374904837725, -0.0530918192795, 0.997885625887) },
    ["middle_03.R"] = { parent = "middle_02.R", rest = CFrame.new(-3.99848020014e-08, 0.31474338788, 8.04324041713e-08, 0.984623264843, 0.15662513641, 0.0773666140758, -0.16822379038, 0.969503997736, 0.178221083835, -0.0470933400711, -0.188495530498, 0.980944265646) },
    ["ring_01.R"] = { parent = "hand.R", rest = CFrame.new(-0.141735047554, 0.546609768362, 0.257361070676, -0.0282588842526, 0.310548656546, -0.950137341324, -0.0494685085127, 0.948917807182, 0.311621343748, 0.998375832102, 0.0558079486411, -0.0114529796185) },
    ["ring_02.R"] = { parent = "ring_01.R", rest = CFrame.new(-1.25023224097e-09, 0.312547205072, -6.70270034761e-09, 0.987761766828, 0.138706964749, 0.0713236981901, -0.146715367068, 0.981488008974, 0.123109257596, -0.0529272430756, -0.132066900356, 0.989826773113) },
    ["ring_03.R"] = { parent = "ring_02.R", rest = CFrame.new(-9.07618223003e-09, 0.231932148789, -2.82218962005e-08, 0.98561242526, 0.129398948958, 0.108738489883, -0.150313421328, 0.965241051532, 0.213812038498, -0.0772918012604, -0.227080656258, 0.970803972495) },
    ["thigh.L"] = { parent = "pelvis", rest = CFrame.new(0.721212137829, 0.360002617041, 0.0914814345764, 0.986074625251, 0.118769371476, 0.116407344419, 0.111137522929, -0.991335549622, 0.0700162770509, 0.123714527979, -0.056104050245, -0.990730564338) },
    ["shin.L"] = { parent = "thigh.L", rest = CFrame.new(-1.89086704543e-07, 1.63290952191, -5.64437924009e-09, 0.991451570418, -0.104871975995, -0.0776250743467, 0.0947112452983, 0.987668213529, -0.12466467021, 0.0897416488068, 0.116247015597, 0.989157756798) },
    ["foot.L"] = { parent = "shin.L", rest = CFrame.new(-9.24267100565e-08, 2.54139809897, 2.25775169604e-08, 0.997357762242, 0.0353751106186, 0.0634515220095, -0.0703275823326, 0.251247589973, 0.965364532027, 0.0182078351227, -0.967276201548, 0.253071580109) },
    ["toe.L"] = { parent = "foot.L", rest = CFrame.new(3.17496332255e-08, 0.788023887259, 2.25775169604e-08, 0.995204707328, 0.00718315845528, -0.0975499500083, 0.0192272364455, 0.963476283391, 0.26710253597, 0.0959057031187, -0.26769731709, 0.958718020344) },
    ["thigh.R"] = { parent = "pelvis", rest = CFrame.new(-0.721212137829, 0.360002617041, 0.0914814345764, 0.986074625251, -0.118769371476, -0.116407344419, -0.111137522929, -0.991335549622, 0.0700162770509, -0.123714527979, -0.056104050245, -0.990730564338) },
    ["shin.R"] = { parent = "thigh.R", rest = CFrame.new(1.89086704543e-07, 1.63290952191, -5.64437924009e-09, 0.991451570418, 0.104871975995, 0.0776250743467, -0.0947112452983, 0.987668213529, -0.12466467021, -0.0897416488068, 0.116247015597, 0.989157756798) },
    ["foot.R"] = { parent = "shin.R", rest = CFrame.new(9.24267100565e-08, 2.54139809897, 2.25775169604e-08, 0.997357762242, -0.0353751106186, -0.0634515220095, 0.0703275823326, 0.251247589973, 0.965364532027, -0.0182078351227, -0.967276201548, 0.253071580109) },
    ["toe.R"] = { parent = "foot.R", rest = CFrame.new(-3.17496332255e-08, 0.788023887259, 2.25775169604e-08, 0.995204707328, -0.00718315845528, 0.0975499500083, -0.0192272364455, 0.963476283391, 0.26710253597, -0.0959057031187, -0.26769731709, 0.958718020344) },
}

local function round(n: number, casas: number): number
    local m = 10 ^ casas
    return math.floor(n * m + 0.5) / m
end

-- Altura da malha em pé no mundo (a MeshPart pode vir girada pelo importador).
local function worldHeight(mesh: MeshPart): number
    local cf, size = mesh.CFrame, mesh.Size
    return math.abs(cf.RightVector.Y) * size.X + math.abs(cf.UpVector.Y) * size.Y + math.abs(cf.LookVector.Y) * size.Z
end

local function yawOf(cf: CFrame): (number, number)
    -- (giro em Y em graus, inclinação em radianos) de uma rotação
    local up = cf.UpVector
    -- atan2 em vez de acos: precisão boa perto de zero (acos perde casas com float32)
    local tilt = math.atan2(math.sqrt(up.X * up.X + up.Z * up.Z), up.Y)
    local r = cf.RightVector
    return math.deg(math.atan2(-r.Z, r.X)), tilt
end

function Contract.Inspect(model)
    assert(typeof(model) == "Instance" and model:IsA("Model"), "Expected an imported Model")
    local errors, meshes, bones = {}, {}, {}
    for _, item in model:GetDescendants() do
        if item:IsA("MeshPart") then table.insert(meshes, item) end
        if item:IsA("Bone") then
            if bones[item.Name] then table.insert(errors, "Duplicate Bone: " .. item.Name) end
            bones[item.Name] = item
        end
        if item:IsA("LuaSourceContainer") then table.insert(errors, "Imported asset unexpectedly contains executable code") end
    end
    if #meshes ~= 1 then table.insert(errors, "Expected exactly one genuine MeshPart; found " .. #meshes) end
    local boneCount = 0
    for _ in bones do boneCount += 1 end
    if boneCount ~= 46 then table.insert(errors, "Expected 46 weighted Bones; found " .. boneCount) end
    local mesh = meshes[1]
    if mesh then
        if mesh.MeshId == "" or mesh.MeshId == "rbxassetid://0" then table.insert(errors, "MeshPart has no uploaded mesh data") end
        if math.abs(worldHeight(mesh) - Contract.HeightStuds) > 0.015 then
            table.insert(errors, "Wrong mesh scale: " .. tostring(worldHeight(mesh)) .. " studs tall")
        end
        if mesh.Name ~= Contract.MeshName then table.insert(errors, "MeshPart needs canonical animation root name") end
    end
    -- Ossos filhos: a pose relativa ao pai é o que as animações usam; precisa bater.
    -- Raiz: o importador pode centralizar e girar o modelo inteiro (ex.: frente +Z do glTF
    -- virando a frente -Z do Roblox). Pele, ossos e animações giram juntos, então isso só
    -- muda para onde o monstro olha; o giro medido vai no relatório e o servidor compensa.
    local maxPositionError, maxAngleError, worstName, worstPos, worstAng = 0, 0, nil, 0, 0
    local root = { yawDegrees = 0, tiltRadians = 0, offsetStuds = 0, centered = false }
    local diffs = {}
    for name, definition in expected do
        local bone = bones[name]
        if not bone then
            table.insert(errors, "Missing Bone: " .. name)
        else
            local expectedParent = definition.parent == Contract.MeshName and mesh or bones[definition.parent]
            if bone.Parent ~= expectedParent then table.insert(errors, "Wrong Bone parent: " .. name) end
            if definition.parent == Contract.MeshName then
                local centered = CFrame.new(-Contract.SourceBoundsCenter) * definition.rest
                local giro = bone.CFrame * centered:Inverse()
                local giroSemCentro = bone.CFrame * definition.rest:Inverse()
                root.centered = true
                if giroSemCentro.Position.Magnitude < giro.Position.Magnitude then
                    giro, root.centered = giroSemCentro, false
                end
                local yaw, tilt = yawOf(giro)
                root.yawDegrees, root.tiltRadians, root.offsetStuds = yaw, tilt, giro.Position.Magnitude
                root.rotation = giro.Rotation
            else
                local delta = definition.rest:ToObjectSpace(bone.CFrame)
                local _, angle = delta:ToAxisAngle()
                local pos, ang = delta.Position.Magnitude, math.abs(angle)
                maxPositionError = math.max(maxPositionError, pos)
                maxAngleError = math.max(maxAngleError, ang)
                if pos / Contract.MaxRestPositionStuds + ang / Contract.MaxRestAngleRadians > worstPos / Contract.MaxRestPositionStuds + worstAng / Contract.MaxRestAngleRadians then
                    worstName, worstPos, worstAng = name, pos, ang
                end
                local len = definition.rest.Position.Magnitude
                if len > 0.05 then
                    table.insert(diffs, bone.CFrame.Position.Magnitude / len)
                end
            end
        end
    end
    -- Causa provável quando os ossos filhos não batem (para saber o que corrigir sem chutar):
    -- rotações zeradas pelo importador, troca de eixo em todos os ossos, ou outra escala.
    local causa = "nenhuma"
    if mesh then
        local mundo = {}
        local function W(name: string): CFrame?
            if mundo[name] then return mundo[name] end
            local def = expected[name]
            if not def then return nil end
            local cf
            if def.parent == Contract.MeshName then
                cf = CFrame.new(-Contract.SourceBoundsCenter) * def.rest
            else
                local pai = W(def.parent)
                if not pai then return nil end
                cf = pai * def.rest
            end
            mundo[name] = cf
            return cf
        end
        local filhos, zerados, conjugados = 0, 0, 0
        local giro = CFrame.Angles(0, math.rad(root.yawDegrees), 0)
        for name, def in expected do
            local bone = bones[name]
            if bone and def.parent ~= Contract.MeshName then
                filhos += 1
                local w, wp = W(name), W(def.parent)
                local _, ang = bone.CFrame.Rotation:ToAxisAngle()
                if w and wp and math.abs(ang) < 0.01 and (bone.CFrame.Position - (w.Position - wp.Position)).Magnitude < 0.05 then
                    zerados += 1
                end
                local conj = giro * def.rest * giro:Inverse()
                local d = conj:ToObjectSpace(bone.CFrame)
                local _, a2 = d:ToAxisAngle()
                if d.Position.Magnitude < 0.05 and math.abs(a2) < 0.01 then conjugados += 1 end
            end
        end
        if maxPositionError > Contract.MaxRestPositionStuds or maxAngleError > Contract.MaxRestAngleRadians then
            if filhos > 0 and zerados >= filhos * 0.9 then
                causa = "rotacoes_zeradas"
            elseif filhos > 0 and conjugados >= filhos * 0.9 and math.abs(root.yawDegrees) > 1 then
                causa = string.format("troca_de_eixo_%d_graus", math.floor(root.yawDegrees + 0.5))
            end
        end
        root.zeradosFilhos, root.conjugadosFilhos, root.filhos = zerados, conjugados, filhos
    end
    local ratioMin, ratioMax = math.huge, -math.huge
    for _, r in diffs do ratioMin, ratioMax = math.min(ratioMin, r), math.max(ratioMax, r) end
    if #diffs == 0 then ratioMin, ratioMax = 1, 1 end
    if causa == "nenhuma" and maxAngleError <= Contract.MaxRestAngleRadians and #diffs > 0
        and math.abs(ratioMax - ratioMin) < 0.002 and math.abs(ratioMin - 1) > 0.002 then
        causa = string.format("escala_%.4f", ratioMin)
    end
    if maxPositionError > Contract.MaxRestPositionStuds or maxAngleError > Contract.MaxRestAngleRadians then
        if causa == "nenhuma" then causa = "desconhecida" end
        table.insert(errors, string.format(
            "Imported bone rest basis differs from the native CFrames; do not enable animation (causa %s; pior osso %s: %.4f studs, %.4f rad; razao de comprimento %.4f..%.4f; giro da raiz %.1f graus)",
            causa, tostring(worstName), worstPos, worstAng, ratioMin, ratioMax, root.yawDegrees))
    end
    root.cause = causa
    if root.offsetStuds > Contract.MaxRootOffsetStuds then
        table.insert(errors, string.format("Imported root is shifted (deslocamento %.4f studs)", root.offsetStuds))
    end
    -- Em pé no mundo = giro da própria MeshPart + giro da raiz juntos. Só o giro em Y é aceito;
    -- deitado/inclinado reprova. O giro em Y vai no relatório e o servidor compensa.
    local importYaw = root.yawDegrees
    if mesh then
        local giroRaiz = root.rotation or CFrame.new()
        local junto = mesh.CFrame.Rotation * giroRaiz
        local yawJunto, tiltJunto = yawOf(junto)
        local meshYaw = select(1, yawOf(mesh.CFrame.Rotation))
        importYaw = yawJunto
        root.meshYawDegrees = meshYaw
        root.worldTiltRadians = tiltJunto
        if tiltJunto > Contract.MaxRootTiltRadians then
            table.insert(errors, string.format("Imported monster would not stand upright (inclinacao %.4f rad; giro da raiz %.2f graus, inclinacao da raiz %.4f rad)",
                tiltJunto, root.yawDegrees, root.tiltRadians))
        end
        -- tamanho da malha no próprio eixo dela = tamanho do arquivo girado pela raiz
        local src = Contract.SourceBoundsSize
        local function linha(v: Vector3): number
            return math.abs(v.X) * src.X + math.abs(v.Y) * src.Y + math.abs(v.Z) * src.Z
        end
        local rx, ry, rz = giroRaiz.RightVector, giroRaiz.UpVector, -giroRaiz.LookVector
        local want = Vector3.new(linha(Vector3.new(rx.X, ry.X, rz.X)), linha(Vector3.new(rx.Y, ry.Y, rz.Y)), linha(Vector3.new(rx.Z, ry.Z, rz.Z)))
        local sizeError = (mesh.Size - want).Magnitude
        root.meshSizeErrorStuds = sizeError
        if sizeError > Contract.MaxMeshSizeErrorStuds then
            table.insert(errors, string.format("Mesh size %s does not match the source turned with the root (esperado %s)",
                tostring(mesh.Size), tostring(want)))
        end
    end
    return {
        ok = #errors == 0, errors = errors, meshCount = #meshes, boneCount = boneCount,
        maxRestPositionErrorStuds = maxPositionError, maxRestAngleErrorRadians = maxAngleError,
        worstBone = worstName, boneLengthRatioMin = ratioMin, boneLengthRatioMax = ratioMax,
        importYawDegrees = importYaw, root = root,
        liveSkinDeformationVerified = false,
    }
end

-- Relatório curto para o teste na nuvem (sem instâncias, só números arredondados).
function Contract.Summary(report: any)
    local root = report.root or {}
    return {
        ok = report.ok, erros = report.errors, ossos = report.boneCount, malhas = report.meshCount,
        pior_osso = report.worstBone, repouso_studs = round(report.maxRestPositionErrorStuds or 0, 5),
        repouso_rad = round(report.maxRestAngleErrorRadians or 0, 5),
        razao_min = round(report.boneLengthRatioMin or 0, 5), razao_max = round(report.boneLengthRatioMax or 0, 5),
        giro_importador_graus = round(report.importYawDegrees or 0, 3), giro_raiz_graus = round(root.yawDegrees or 0, 3),
        giro_malha_graus = round(root.meshYawDegrees or 0, 3), inclinacao_raiz_rad = round(root.tiltRadians or 0, 5),
        deslocamento_raiz_studs = round(root.offsetStuds or 0, 5), raiz_centralizada = root.centered,
        inclinacao_no_mundo_rad = round(root.worldTiltRadians or 0, 5),
        erro_tamanho_malha = round(root.meshSizeErrorStuds or 0, 5),
        causa_provavel = root.cause, filhos = root.filhos, filhos_zerados = root.zeradosFilhos,
        filhos_troca_de_eixo = root.conjugadosFilhos,
    }
end

function Contract.Prepare(model, normalizeScale)
    assert(typeof(model) == "Instance" and model:IsA("Model"), "Expected an imported Model")
    local meshes = {}
    for _, item in model:GetDescendants() do
        if item:IsA("Animator") and #item:GetPlayingAnimationTracks() > 0 then
            error("Prepare the static import before playing animation")
        end
        if item:IsA("MeshPart") then table.insert(meshes, item) end
    end
    if #meshes ~= 1 then return Contract.Inspect(model) end
    local mesh = meshes[1]
    local importedHeight = worldHeight(mesh)
    if normalizeScale and importedHeight > 0 and math.abs(importedHeight - Contract.HeightStuds) > 0.0005 then
        -- Model scaling also scales Bone rest translations; vertex weights stay unchanged.
        model:ScaleTo(model:GetScale() * Contract.HeightStuds / importedHeight)
    end
    mesh.Name = Contract.MeshName
    local report = Contract.Inspect(model)
    report.importedHeightStuds = importedHeight
    return report
end

return Contract
