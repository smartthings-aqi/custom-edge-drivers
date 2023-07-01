local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local constants = require "st.zigbee.constants"
local defaults = require "st.zigbee.defaults"
local utils = require "st.utils"
local log = require "log"
local xiaomi_utils = require "xiaomi_utils"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local atmos_Pressure = capabilities ["legendabsolute60149.atmosPressure"]

local tempearture_value_attr_handler = function(driver, device, value, zb_rx)
  local temperature = value.value / 100

  if temperature < -99 or temperature > 99 then
    log.info("Temperature value out of range: " .. temperature)
    return
  end

  device:emit_event(capabilities.temperatureMeasurement.temperature({ value = temperature, unit = "C" }))
  
  local alarm = "cleared"
  if temperature > 60 then
    alarm = "heat"
  elseif temperature < -20 then
    alarm = "freeze"
  end
  
  device:emit_event(capabilities.temperatureAlarm.temperatureAlarm(alarm))
end

local humidity_value_attr_handler = function(driver, device, value, zb_rx)
  local percent = utils.clamp_value(value.value / 100, 0.0, 100.0)
  if percent<99 then -- filter out spurious values
    device:emit_event(capabilities.relativeHumidityMeasurement.humidity(percent))
  end
end

local pressure_value_attr_handler = function(driver, device, value, zb_rx)
  local mBar = value.value
  device:emit_event(capabilities.atmosphericPressureMeasurement.atmosphericPressure({value = utils.round(mBar/10), unit = "kPa"}))
  device:emit_event(atmos_Pressure.atmosPressure(mBar))
end

local function refresh_handler(driver, device, command)
  device:send(zcl_clusters.TemperatureMeasurement.attributes.MeasuredValue:read(device))
  device:send(zcl_clusters.RelativeHumidity.attributes.MeasuredValue:read(device))
  device:send(zcl_clusters.PressureMeasurement.attributes.MeasuredValue:read(device))
end

local zigbee_temp_driver_template = {
  supported_capabilities = {
    capabilities.relativeHumidityMeasurement,
    capabilities.atmosphericPressureMeasurement,
    capabilities.temperatureMeasurement,
    capabilities.battery,
    capabilities.temperatureAlarm,
  },
  use_defaults = true,
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = refresh_handler
    }
  },
  zigbee_handlers = {
    attr = {
      [zcl_clusters.basic_id] = xiaomi_utils.basic_id,
      [zcl_clusters.TemperatureMeasurement.ID] = {
        [zcl_clusters.TemperatureMeasurement.attributes.MeasuredValue.ID] = tempearture_value_attr_handler
      },
      [zcl_clusters.RelativeHumidity.ID] = {
        [zcl_clusters.RelativeHumidity.attributes.MeasuredValue.ID] = humidity_value_attr_handler
      },
      [zcl_clusters.PressureMeasurement.ID] = {
        [zcl_clusters.PressureMeasurement.attributes.MeasuredValue.ID] = pressure_value_attr_handler
      }
    }
  },
}

defaults.register_for_default_handlers(zigbee_temp_driver_template, zigbee_temp_driver_template.supported_capabilities)
local driver = ZigbeeDriver("xiaomi_temp", zigbee_temp_driver_template)
driver:run()