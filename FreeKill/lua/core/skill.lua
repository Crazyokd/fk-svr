-- SPDX-License-Identifier: GPL-3.0-or-later

--- Skill用来描述一个技能。
---
---@class Skill : Object
---@field public name string @ 技能名
---@field public trueName string @ 技能真名
---@field public package Package @ 技能所属的包
---@field public frequency Frequency @ 技能发动的频繁程度，通常compulsory（锁定技）及limited（限定技）用的多。
---@field public visible boolean @ 技能是否会显示在游戏中
---@field public mute boolean @ 决定是否关闭技能配音
---@field public no_indicate boolean @ 决定是否关闭技能指示线
---@field public global boolean @ 决定是否是全局技能
---@field public anim_type string|AnimationType @ 技能类型定义
---@field public related_skills Skill[] @ 和本技能相关的其他技能，有时候一个技能实际上是通过好几个技能拼接而实现的。
---@field public attached_equip string @ 属于什么装备的技能？
---@field public relate_to_place string @ 主将技/副将技
---@field public switchSkillName string @ 转换技名字
---@field public times integer @ 技能剩余次数，负数不显示，正数显示
---@field public attached_skill_name string @ 给其他角色添加技能的名称
local Skill = class("Skill")

---@alias Frequency integer

Skill.Frequent = 1
Skill.NotFrequent = 2
Skill.Compulsory = 3
Skill.Limited = 4
Skill.Wake = 5
Skill.Quest = 6

--- 构造函数，不可随意调用。
---@param name string @ 技能名
---@param frequency Frequency @ 技能发动的频繁程度，通常compulsory（锁定技）及limited（限定技）用的多。
function Skill:initialize(name, frequency)
  -- TODO: visible, lord, etc
  self.name = name
  -- skill's package is assigned when calling General:addSkill
  -- if you need skills that not belongs to any general (like 'jixi')
  -- then you should use general function addRelatedSkill to assign them
  self.package = { extensionName = "standard" }
  self.frequency = frequency
  self.visible = true
  self.lordSkill = false
  self.cardSkill = false
  self.mute = false
  self.no_indicate = false
  self.anim_type = ""
  self.related_skills = {}
  self.attachedKingdom = {}
  self._extra_data = {}

  local name_splited = name:split("__")
  self.trueName = name_splited[#name_splited]

  if string.sub(name, 1, 1) == "#" then
    self.visible = false
  end
  if string.sub(name, #name) == "$" then
    self.name = string.sub(name, 1, #name - 1)
    self.lordSkill = true
  end

  self.attached_equip = nil
  self.relate_to_place = nil

  self.attached_skill_name = nil
end

function Skill:__index(k)
  if k == "cost_data" then
    return Fk:currentRoom().skill_costs[self.name]
  else
    return self._extra_data[k]
  end
end

function Skill:__newindex(k, v)
  if k == "cost_data" then
    Fk:currentRoom().skill_costs[self.name] = v
  else
    rawset(self, k, v)
  end
end

function Skill:__tostring()
  return "<Skill " .. self.name .. ">"
end

--- 为一个技能增加相关技能。
---@param skill Skill @ 技能
function Skill:addRelatedSkill(skill)
  table.insert(self.related_skills, skill)
  Fk.related_skills[self.name] = Fk.related_skills[self.name] or {}
  table.insert(Fk.related_skills[self.name], skill)
end

--- 确认本技能是否为装备技能。
---@param player Player
---@return boolean
function Skill:isEquipmentSkill(player)
  if player then
    local filterSkills = Fk:currentRoom().status_skills[FilterSkill] or Util.DummyTable
    for _, filter in ipairs(filterSkills) do
      local result = filter:equipSkillFilter(self, player)
      if result then
        return true
      end
    end
  end

  return self.attached_equip and type(self.attached_equip) == 'string' and self.attached_equip ~= ""
end

--- 判断技能是不是对于某玩家而言失效了。
---
--- 它影响的是hasSkill，但也可以单独拿出来判断。
---@param player Player @ 玩家
---@return boolean
function Skill:isEffectable(player)
  if self.cardSkill or self.permanent_skill then
    return true
  end

  local nullifySkills = Fk:currentRoom().status_skills[InvaliditySkill] or Util.DummyTable
  for _, nullifySkill in ipairs(nullifySkills) do
    if self.name ~= nullifySkill.name and nullifySkill:getInvalidity(player, self) then
      return false
    end
  end

  for mark, value in pairs(player.mark) do -- 耦合 MarkEnum.InvalidSkills ！
    if mark == MarkEnum.InvalidSkills then
      if table.contains(value, self.name) then
        return false
      end
    elseif mark:startsWith(MarkEnum.InvalidSkills .. "-") and table.contains(value, self.name) then
      for _, suffix in ipairs(MarkEnum.TempMarkSuffix) do
        if mark:find(suffix, 1, true) then
          return false
        end
      end
    end
  end

  return true
end

--- 为技能增加所属势力，需要在隶属特定势力时才能使用此技能。
--- 案例：手杀文鸯
function Skill:addAttachedKingdom(kingdom)
  table.insertIfNeed(self.attachedKingdom, kingdom)
end

--- 判断某个技能是否为转换技
function Skill:isSwitchSkill()
  return self.switchSkillName and type(self.switchSkillName) == 'string' and self.switchSkillName ~= ""
end

--判断技能是否为角色技能
---@param player Player
---@return boolean
function Skill:isPlayerSkill(player)
  return not (self:isEquipmentSkill(player) or self.name:endsWith("&"))
end

---@return integer
function Skill:getTimes()
  local ret = self.times
  if not ret then
    return -1
  elseif type(ret) == "function" then
    ret = ret(self)
  end
  return ret
end

-- 获得此技能时，触发此函数
---@param player ServerPlayer
---@param is_start boolean?
function Skill:onAcquire(player, is_start)
  local room = player.room

  if self.attached_skill_name then
    for _, p in ipairs(room.alive_players) do
      if p ~= player then
        room:handleAddLoseSkills(p, self.attached_skill_name, nil, false, true)
      end
    end
  end
end

-- 失去此技能时，触发此函数
---@param player ServerPlayer
---@param is_death boolean?
function Skill:onLose(player, is_death)
  local room = player.room
  if self.attached_skill_name then
    local skill_owners = table.filter(room.alive_players, function (p)
      return p:hasSkill(self, true)
    end)
    if #skill_owners == 0 then
      for _, p in ipairs(room.alive_players) do
        room:handleAddLoseSkills(p, "-" .. self.attached_skill_name, nil, false, true)
      end
    elseif #skill_owners == 1 then
      local p = skill_owners[1]
      room:handleAddLoseSkills(p, "-" .. self.attached_skill_name, nil, false, true)
    end
  end

end

return Skill
