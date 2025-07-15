--- Event system for screw.nvim
---
--- This module provides a simple event system for plugin hooks and
--- inter-module communication.
---

local M = {}

--- Event listeners registry
M.listeners = {}

--- Emit an event to all registered listeners
---@param event_name string
---@param data table?
function M.emit(event_name, data)
  local event_listeners = M.listeners[event_name]
  if not event_listeners then
    return
  end

  for _, listener in ipairs(event_listeners) do
    pcall(listener, data or {})
  end
end

--- Register an event listener
---@param event_name string
---@param callback function
function M.on(event_name, callback)
  if not M.listeners[event_name] then
    M.listeners[event_name] = {}
  end

  table.insert(M.listeners[event_name], callback)
end

--- Remove an event listener
---@param event_name string
---@param callback function
function M.off(event_name, callback)
  local event_listeners = M.listeners[event_name]
  if not event_listeners then
    return
  end

  for i, listener in ipairs(event_listeners) do
    if listener == callback then
      table.remove(event_listeners, i)
      break
    end
  end
end

--- Remove all listeners for an event
---@param event_name string
function M.clear(event_name)
  M.listeners[event_name] = nil
end

--- Remove all event listeners
function M.clear_all()
  M.listeners = {}
end

--- Get list of registered events
---@return string[]
function M.get_events()
  return vim.tbl_keys(M.listeners)
end

--- Get listener count for an event
---@param event_name string
---@return number
function M.get_listener_count(event_name)
  local event_listeners = M.listeners[event_name]
  return event_listeners and #event_listeners or 0
end

return M