local stub = {}

local function merge(into, from)
  for key, value in pairs(from) do
    if type(value) == "table" and type(into[key]) == "table" then
      merge(into[key], value)
    elseif type(value) == "table" then
      into[key] = merge({}, value)
    else
      into[key] = value
    end
  end
  return into
end

local function record(kind, ...)
  table.insert(stub.calls, { kind = kind, args = { ... } })
end

local Item = {}
Item.__index = Item

function Item:set(props)
  record("set", self.name, props)
  merge(self.props, props)
end

function Item:subscribe(events, handler)
  if type(events) == "string" then events = { events } end
  record("subscribe", self.name, events)
  for _, event in ipairs(events) do
    self.handlers[event] = self.handlers[event] or {}
    table.insert(self.handlers[event], handler)
  end
end

function Item:query()
  return self.props
end

function stub.reset()
  stub.calls = {}
  stub.items = {}
  stub.responses = {}
  stub.bar_props = {}
  stub.default_props = {}
end

function stub.add(kind, name, ...)
  local extra = { ... }
  local props = type(extra[#extra]) == "table" and extra[#extra] or {}
  local item = setmetatable({ kind = kind, name = name, props = merge({}, props), handlers = {} }, Item)
  if kind == "bracket" then item.members = extra[1] end
  record("add", kind, name, ...)
  stub.items[name] = item
  return item
end

function stub.set(name, props)
  record("set", name, props)
  if stub.items[name] then merge(stub.items[name].props, props) end
end

function stub.bar(props)
  record("bar", props)
  merge(stub.bar_props, props)
end

function stub.default(props)
  record("default", props)
  merge(stub.default_props, props)
end

function stub.exec(cmd, callback)
  record("exec", cmd)
  local response = ""
  for _, entry in ipairs(stub.responses) do
    local pattern, answer = entry[1], entry[2]
    if cmd:find(pattern) then
      response = type(answer) == "function" and answer(cmd) or answer
      break
    end
  end
  if callback then callback(response, 0) end
end

function stub.animate(curve, frames, fn)
  record("animate", curve, frames)
  fn()
end

function stub.trigger(event)
  record("trigger", event)
end

function stub.begin_config() record("begin_config") end
function stub.end_config() record("end_config") end
function stub.event_loop() record("event_loop") end

function stub.fire(item, event, env)
  env = merge({ NAME = item.name, SENDER = event }, env or {})
  for _, handler in ipairs(item.handlers[event] or {}) do
    handler(env)
  end
end

function stub.find(kind, predicate)
  local found = {}
  for _, call in ipairs(stub.calls) do
    if call.kind == kind and (not predicate or predicate(table.unpack(call.args))) then
      table.insert(found, call)
    end
  end
  return found
end

stub.reset()
return stub
