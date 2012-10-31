local core = require("core")
local Emitter = core.Emitter

local hsm = {}

local StateMachine = Emitter:extend()

function StateMachine:defineStates(states)
  local index = getmetatable(self).__index
  local types = {'react', 'entry', 'exit'}

  function createState(stateName)
    local state = {}
    state.name = stateName
    for _, actionType in ipairs(types) do
      local methodName = '_' .. actionType .. stateName
      if index[methodName] then
        state[actionType] = index[methodName]
      end
    end
    return state
  end

  self.states = {}
  for name, _ in pairs(states) do
    self.states[name] = createState(name)
  end
end

function StateMachine:react(...)
  local targetState = self.state.react(self, ...)
  if targetState and targetState ~= self.state then
    self:_transit(targetState)
  end
  return targetState
end

function StateMachine:_transit(targetState)
  self:_runExitActions(self.state)
  self:_runEntryActions(targetState)
  self.state = targetState
end

function StateMachine:_runExitActions(sourceState)
  if sourceState.exit then
    sourceState.exit(self)
  end
end

function StateMachine:_runEntryActions(targetState)
  if targetState.entry then
    targetState.entry(self)
  end
end


local function clone(table)
  local ret = {}
  for k, v in pairs(table) do
    ret[k] = v
  end
  return ret
end

local function indexOf(table, elem)
  for i = 1, #table do
    if table[i] == elem then
      return i
    end
  end
  return nil
end

local HierarchicalStateMachine = Emitter:extend()

function HierarchicalStateMachine:defineStates(states)
  local index = getmetatable(self).__index
  local types = {'react', 'entry', 'exit'}

  function createState(stateName)
    local state = {}
    for _, actionType in ipairs(types) do
      local methodName = '_' .. actionType .. stateName
      if index[methodName] then
        state[actionType] = index[methodName]
      end
    end
    return state
  end

  self.states = {}
  self.paths = {}

  function addState(name, children, parentPath)
    local state = createState(name)
    self.states[name] = state

    local path = clone(parentPath)
    path[#path + 1] = state
    self.paths[state] = path

    for n, c in pairs(children) do
      addState(n, c, path)
    end
  end

  for name, children in pairs(states) do
    addState(name, children, {})
  end
end

function HierarchicalStateMachine:react(...)
  local path, i
  local state = self.state
  local targetState
  repeat
    targetState = state.react(self, ...)
    if targetState then -- consumed
      if targetState ~= self.state then
        self:_transit(targetState)
      end
      break
    end

    if i then
      i = i - 1
    else
      path = self.paths[state]
      i = #path - 1
    end
    state = path[i]
  until i < 1
  return targetState
end

function HierarchicalStateMachine:_transit(targetState)
  local lca = self:_getLCA(self.state, targetState)
  self:_runExitActions(self.state, lca)
  self:_runEntryActions(lca, targetState)
  self.state = targetState
end

function HierarchicalStateMachine:_runExitActions(sourceState, lca)
  local path = self.paths[sourceState]
  for i = #path, 1, -1 do
    local state = path[i]
    if state == lca then
      break
    end
    if state.exit then
      state.exit(self)
    end
  end
end

function HierarchicalStateMachine:_runEntryActions(lca, targetState)
  local path = self.paths[targetState]
  local i = (indexOf(path, lca) or 0) + 1
  while i <= #path do
    local state = path[i]
    if state.entry then
      state.entry(self)
    end
    i = i + 1
  end
end

function HierarchicalStateMachine:_isAncestorOf(ancestor, descendant)
  if descendant then
    local path = self.paths[descendant]
    for i = #path, 1, -1 do
      if path[i] == ancestor then
        return true
      end
    end
  end
  return false
end

function HierarchicalStateMachine:_getLCA(a, b)
  if a then
    local path = self.paths[a]
    for i = #path, 1, -1 do
      if self:_isAncestorOf(path[i], b) then
        return path[i]
      end
    end
  end
  return nil
end

hsm.StateMachine = StateMachine
hsm.HierarchicalStateMachine = HierarchicalStateMachine
return hsm
