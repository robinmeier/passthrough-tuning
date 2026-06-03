local mod = require "core/mods"
local core = require("passthrough/lib/core")
local utils = require("passthrough/lib/utils")
local tab = require "tabutil"

local api = {}
local config = {}
local state = {}
local default_port_state = {
  active = 1,
  target = 1,
  input_channel = 1,
  output_channel = 1,
  send_clock = 1,
  quantize_midi = 1,
  current_scale = 1,
  root_note = 0,
  cc_limit = 1,
  crow_notes = 1,
  crow_cc_outputs = 1,
  crow_cc_selection_a = 1,
  crow_cc_selection_b = 1,
  tuning_mode = 1,
  tuning_file = 1,
  tuning_root = 60,
  tuning_voices = 1,
  tuning_base_ch = 1,
  tuning_pb_range = 2,
}

-- MOD NORNS OVERRIDES --

local midi_add = _norns.midi.add
local midi_remove = _norns.midi.remove
local script_clear = norns.script.clear

_norns.midi.add = function(id, name, dev)
  midi_add(id, name, dev)
  update_devices()
end

_norns.midi.remove = function(id)
  midi_remove(id)
  update_devices()
end

norns.script.clear = function()
  script_clear()
  update_devices()
end

-- STATE FUNCTIONS --
function write_state()
  local f = io.open(_path.data.."passthrough.state","w+")
  io.output(f)
  io.write("return {")
  local counter = 0
  for k, v in pairs(state) do
    counter = counter + 1

    if counter~=1 then
      io.write(",")
    end
    io.write("["..k.."] =")
    io.write("{ active="..v.active..",")
    io.write("dev_port="..v.dev_port..",")
    io.write("target="..v.target..",")
    io.write("input_channel="..v.input_channel..",")
    io.write("output_channel="..v.output_channel..",")
    io.write("send_clock="..v.send_clock..",")
    io.write("quantize_midi="..v.quantize_midi..",")
    io.write("current_scale="..v.current_scale..",")
    io.write("root_note="..v.root_note..",")
    io.write("cc_limit="..v.cc_limit..",")
    io.write("crow_notes="..v.crow_notes..",")
    io.write("crow_cc_outputs="..v.crow_cc_outputs..",")
    io.write("crow_cc_selection_a="..v.crow_cc_selection_a..",")
    io.write("crow_cc_selection_b="..v.crow_cc_selection_b..",")
    io.write("tuning_mode="..v.tuning_mode..",")
    io.write("tuning_file="..v.tuning_file..",")
    io.write("tuning_root="..v.tuning_root..",")
    io.write("tuning_voices="..v.tuning_voices..",")
    io.write("tuning_base_ch="..v.tuning_base_ch..",")
    io.write("tuning_pb_range="..v.tuning_pb_range.."}")
  end
  io.write("}\n")
  io.close(f)
end

function read_state()
  local f = io.open(_path.data.."passthrough.state")
  if f ~= nil then
    io.close(f)
    local ok, loaded = pcall(dofile, _path.data.."passthrough.state")
    if ok and type(loaded) == "table" then
      state = loaded
    end
  end

  for i = 1, tab.count(state) do
    if state[i].cc_limit == nil then
      state[i].cc_limit = 1
    end

    core.build_scale(state[i].root_note, state[i].current_scale, state[i].dev_port)
  end
end

function assign_state()
  for i=1, tab.count(config) do
    if state[i] then
      for k, v in ipairs(state[i]) do
        config[k].action(v)
      end
    end
  end
end

local function refresh_musicutil_tuning()
  for i = 1, 16 do
    if state[i] and state[i].active == 2 and state[i].tuning_mode == 2 then
      local t = core.port_tunings[i]
      if t then
        core.apply_musicutil_patch(t, state[i].tuning_root)
        return
      end
    end
  end
  core.remove_musicutil_patch()
end

-- HOOKS --
mod.hook.register("system_post_startup", "read passthrough state", function()
  read_state()
  update_devices()
end)

mod.hook.register("system_pre_shutdown", "write passthrough state", function()
  write_state()
end)

mod.hook.register("script_post_cleanup", "passthrough post cleanup", function()
  update_devices()
end)

mod.hook.register("script_pre_init", "passthrough", function()
  -- tweak global environment here ahead of the script `init()` function being called
  local script_init = init
  
  init = function()
      script_init()
      update_devices()
  end
end)

-- ACTIONS + EVENTS --
function create_config()
  local config={}

  for k, v in pairs(core.ports) do
    if state[v.port] == nil then
      state[v.port] = default_port_state
    else
        -- ensure that the state is up to date with changing api keys
        for key, value in pairs(default_port_state) do
          if state[v.port][key] == nil then
            state[v.port][key] = value
          end
        end
    end
    
    state[v.port].dev_port = v.port

    -- config creates an object for each passthru parameter
    config[k] = {
      active = {
        param_type = "option",
        id = "active",
        name = "Active",
        options = core.toggles,
        action = function(value)
          refresh_musicutil_tuning()
        end
      },
      target = {
        param_type = "option",
        id = "target",
        name = "Target",
        options = core.targets[v.port],
        action = function(value)
          core.port_connections[v.port] = core.set_target_connections(v.port, value)
        end,
        formatter = function(value)
          if value == 1 then return core.targets[v.port][value] end
          local target = core.targets[v.port][value]
          local found_port = utils.table_find_value(core.ports, function(_,v) return target == v.port end)
          if found_port then return found_port.name end
          
          return "Saved port unconnected"
        end
      },
      input_channel = {
        param_type = "option",
        id = "input_channel",
        name = "Input channel",
        options = core.input_channels
      },
      output_channel = {
        param_type = "option",
        id = "output_channel",
        name = "Output channel",
        options = core.output_channels
      },
      send_clock = {
        param_type = "option",
        id = "send_clock",
        name = "Clock out",
        options = core.toggles,
        action = function(value)
            if value == 1 then
                core.stop_clocks(v.port)
            end
        end
        },
      quantize_midi = {
        param_type = "option",
        id = "quantize_midi",
        name = "Quantize midi",
        options = core.toggles
      },
      root_note = {
        param_type = "number",
        id = "root_note",
        name = "Root",
        minimum = 0,
        maximum = 11,
        formatter = core.root_note_formatter,
        action = function()
            core.build_scale(state[k].root_note, state[k].current_scale, k)
        end
      },
      current_scale = {
          param_type = "option",
          id = "current_scale",
          name = "Scale",
          options = core.scale_names,
          action = function()
            core.build_scale(state[k].root_note, state[k].current_scale, k)
          end
      },
      cc_limit = {
        param_type = "option",
        id = "cc_limit",
        name = "CC limit",
        options = core.cc_limits
      },
      crow_notes = {
        param_type = "option",
        id = "crow_notes",
        name = "Crow note output",
        options = core.crow_notes
      },
      crow_cc_outputs = {
        param_type = "option",
        id = "crow_cc_outputs",
        name = "Crow cc output",
        options = core.crow_cc_outputs
      },
      crow_cc_selection_a = {
        param_type = "number",
        id = "crow_cc_selection_a",
        name = "Crow cc out a",
        minimum = 1,
        maximum = 128,
      },
      crow_cc_selection_b = {
        param_type = "number",
        id = "crow_cc_selection_b",
        name = "Crow cc out b",
        minimum = 1,
        maximum = 128,
      },
      tuning_mode = {
        param_type = "option",
        id = "tuning_mode",
        name = "Tuning",
        options = core.tuning_modes,
        action = function(value)
          if value == 3 then
            local vc = core.tuning_voice_counts[state[v.port].tuning_voices]
            core.setup_voice_pool(v.port, vc, state[v.port].tuning_base_ch)
          end
          refresh_musicutil_tuning()
        end
      },
      tuning_file = {
        param_type = "option",
        id = "tuning_file",
        name = "Tuning file",
        options = core.tuning_file_names,
        action = function(value)
          core.load_port_tuning(v.port, value)
          refresh_musicutil_tuning()
        end
      },
      tuning_root = {
        param_type = "number",
        id = "tuning_root",
        name = "Tuning root",
        minimum = 0,
        maximum = 127,
        formatter = core.root_note_formatter,
        action = function(value)
          refresh_musicutil_tuning()
        end
      },
      tuning_voices = {
        param_type = "option",
        id = "tuning_voices",
        name = "PB voices",
        options = core.tuning_voice_options,
        action = function(value)
          if state[v.port].tuning_mode == 3 then
            local vc = core.tuning_voice_counts[value]
            core.setup_voice_pool(v.port, vc, state[v.port].tuning_base_ch)
          end
        end
      },
      tuning_base_ch = {
        param_type = "number",
        id = "tuning_base_ch",
        name = "PB base ch",
        minimum = 1,
        maximum = 16,
        action = function(value)
          if state[v.port].tuning_mode == 3 then
            local vc = core.tuning_voice_counts[state[v.port].tuning_voices]
            core.setup_voice_pool(v.port, vc, value)
          end
        end
      },
      tuning_pb_range = {
        param_type = "option",
        id = "tuning_pb_range",
        name = "PB range (st)",
        options = core.tuning_pb_range_options,
      },
    }

    config[k].target.action(state[k].target)
    config[k].root_note.action(state[k].root_note, state[k].current_scale, k)
    config[k].current_scale.action(state[k].root_note, state[k].current_scale, k)
  end

  return config
end

function device_event(id, data)
    if state == nil then return end
    local port = core.get_port_from_id(id)
    port_config = state[port]
    

    if port_config ~= nil and port_config.active == 2 then
      core.device_event(
        port,
        port_config.target,
        port_config.input_channel,
        port_config.output_channel,
        port_config.send_clock,
        port_config.quantize_midi,
        port_config.current_scale,
        port_config.cc_limit,
        port_config.crow_notes,
        port_config.crow_cc_outputs,
        port_config.crow_cc_selection_a,
        port_config.crow_cc_selection_b,
        port_config.tuning_mode,
        port_config.tuning_root,
        core.tuning_pb_range_values[port_config.tuning_pb_range] or 2,
        data)
      
      api.user_event(id, data)
    end
end

core.origin_event = device_event -- assign device_event to core origin

function update_devices()
  core.setup_midi()
  core.scan_tuning_files()
  config = create_config()
  assign_state()
  for port, s in pairs(state) do
    core.load_port_tuning(port, s.tuning_file)
    if s.tuning_mode == 3 then
      local vc = core.tuning_voice_counts[s.tuning_voices] or 1
      core.setup_voice_pool(port, vc, s.tuning_base_ch)
    end
  end
  refresh_musicutil_tuning()
end

function update_parameter(p, index, dir)
  -- update options
  if p.param_type == "option" then
    state[index][p.id] = util.clamp(state[index][p.id] + dir, 1, #p.options)
  end

  -- generate scale
  if p.param_type == "number" then
    state[index][p.id] = util.clamp(state[index][p.id] + dir, p.minimum, p.maximum)
  end

  if p.action and type(p.action == "function") then
    p.action(state[index][p.id])
  end

  write_state()
end

function format_parameter(p, index) 
  if p.formatter and type(p.formatter == "function") then
    return p.formatter(state[index][p.id])
  end

  if p.param_type == "option" then
    return p.options[state[index][p.id]]
  end

  return state[index][p.id]
end

local get_menu_pagination_table = function()
    local t = {}
    
    local counter = 1
    for k, v in pairs(config) do
      t[counter] = k
      counter = counter + 1
    end
    
    return t
end

-- MOD MENU --
local screen_order = {"active", "target", "input_channel", "output_channel", "send_clock", "quantize_midi", "root_note", "current_scale", "cc_limit", "crow_notes", "crow_cc_outputs", "crow_cc_selection_a", "crow_cc_selection_b", "tuning_mode", "tuning_file", "tuning_root", "tuning_voices", "tuning_base_ch", "tuning_pb_range", "midi_panic"}
local m = {
  list=screen_order,
  pos=0,
  page=1,
  len=tab.count(screen_order),
  show_hint = true,
  display_panic = false,
  display_devices = {}
}

local toggle_display_panic = function()
  clock.run(function()
      m.display_panic=true
      clock.sleep(0.5)
      m.display_panic=false
      mod.menu.redraw()
  end)
end

m.key = function(n, z)
  if n == 2 and z == 1 then
    mod.menu.exit()
  end
  if n == 3 and z == 1 then
    m.page = util.wrap(m.page + z, 1, tab.count(m.display_devices))
    m.pos = 0
    m.show_hint = false
    mod.menu.redraw()
  end
end

m.enc = function(n, d)
  m.show_hint = false
  
  if core.has_devices == true then 
      if n == 2 then
        if m.pos == 0 and d == -1 then
          m.show_hint = true
        end
        m.pos = util.clamp(m.pos + d, 0, m.len - 1)
      end
    
      if n == 3 then
        local page_port = m.display_devices[m.page]
        if m.list[m.pos+1] == "midi_panic" then
          core.stop_all_notes()
          toggle_display_panic()
        else
          update_parameter(config[page_port][m.list[m.pos + 1]], page_port, d)
        end
      end 
      mod.menu.redraw()
  end
end

m.redraw = function()
  screen.clear()

  if core.has_devices == true then
      
      local page_port = m.display_devices[m.page]
      for i=1,6 do
        if (i > 2 - m.pos) and (i < m.len - m.pos + 3) then
          screen.move(0,10*i)
          local line = m.list[i+m.pos-2]
          if(i==3) then
            screen.level(15)
          else
            screen.level(4)
          end
    
          if line == "midi_panic" then
            screen.text("Midi panic : ")
            screen.rect(50, (10*i)-4.5, 5, 5)
            screen.level(m.display_panic and 15 or 4)
            screen.fill()
          else
            local param = config[page_port][line]
            screen.text(param.name .. " : " .. format_parameter(param, page_port))
          end
        end
      end
      screen.rect(0, 0, 140, 13)
      screen.level(0)
      screen.fill()
      screen.level(15)
      screen.move(0, 10)
      screen.text(page_port)
      screen.move(120, 10)
      screen.text_right(string.upper(core.ports[page_port].name))
      if m.show_hint then
        screen.level(2)
        screen.move(0, 20)
        screen.text("E2 scroll")
        screen.move(42, 20)
        screen.text("E3 select")
        screen.move(120, 20)
        screen.text_right("K3 port")
      end
      screen.update()
  else
     screen.level(15)
     screen.move(0, 20)
     screen.text("No devices connected") 
     screen.update()
  end
end

m.init = function()
  m.page = 1
  m.pos = 0
  m.show_hint=true
  update_devices()
  m.display_devices = get_menu_pagination_table()
end

m.deinit = function() 
  write_state()
end

mod.menu.register(mod.this_name, m)

-- API --
api.get_state = function()
  return state
end

api.get_connections = function()
  return core.port_connections
end

api.get_port_from_id = function(id)
  return core.get_port_from_id(id)
end

api.user_event = core.user_event

return api
