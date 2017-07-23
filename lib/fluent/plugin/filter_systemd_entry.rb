# frozen_string_literal: true
require "fluent/config/error"
require "fluent/plugin/filter"
require "fluent/plugin/systemd/entry_helpers"

module Fluent
  module Plugin
    # Fluentd systemd/journal filter plugin
    class SystemdEntryFilter < Filter
      Fluent::Plugin.register_filter("systemd_entry", self)

      config_param :field_map, :hash, default: {}
      config_param :field_map_strict, :bool, default: false
      config_param :fields_strip_underscores, :bool, default: false
      config_param :fields_lowercase, :bool, default: false

      def configure(conf)
        super
        # will raise Fluent::ConfigError on bad filter config
        @mutator = SystemdMutatorBuilder.new(@config_root_section).build
        if @field_map_strict && @field_map.empty?
          log.warn("`field_map_strict` set to true with empty `field_map`, expect no fields")
        end
      end

      def filter(_tag, _time, entry)
        @mutator.run(entry)
      end
    end
  end
end
