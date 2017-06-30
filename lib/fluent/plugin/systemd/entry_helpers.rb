# frozen_string_literal: true
require "fluent/configurable"
require "fluent/config/error"
require "systemd/journal_entry_mutator"

module Fluent
  module Plugin
    # Builder with basic fluentd integrations suitable for use in any systemd
    # plugin for creating `Systemd::JournalEntryMutator` objects i.e. the
    # contructor takes a `Fluent::Config::Section` object and any
    # `Systemd::JournalEntryMutator::OptionError` is re-raised as a
    # `Fluent::ConfigError`
    class SystemdMutatorBuilder
      # config - Fluent::Config::Section - The mutator config options need to be
      #          at the root of the config section object.
      def initialize(config)
        @config = config
      end

      # Raises Fluent::ConfigError if options are invalid. Otherwise, returns
      # a configured Systemd::JournalEntryMutator instance
      def build
        Systemd::JournalEntryMutator.new(**@config.to_h)
      rescue Systemd::JournalEntryMutator::OptionError => e
        raise Fluent::ConfigError, e.message
      end
    end

    # Mixin that augments systemd fluentd plugins with the ability to
    # configure and embed the systemd journal entry mutator functionality.
    # When included, the mutator can be configured via the <entry>
    # block in the plugin's config and then called via the `mutate` method.
    module SystemdMutableEntry
      include Fluent::Configurable

      config_section :entry, param_name: "entry_opts", required: false, multi: false do
        config_param :field_map, :hash, default: {}
        config_param :field_map_strict, :bool, default: false
        config_param :fields_strip_underscores, :bool, default: false
        config_param :fields_lowercase, :bool, default: false
      end

      def configure(conf)
        super
        @mutator = nil
        unless @entry_opts.nil?
          # will raise Fluent::ConfigError on bad entry config
          @mutator = SystemdMutatorBuilder.new(@entry_opts).build
          if @entry_opts[:field_map_strict] && @entry_opts[:field_map].empty?
            log.warn("`field_map_strict` set to true with empty `field_map`, expect no fields")
          end
        end
      end

      # If a valid mutator exists, proxy to the mutator `run` method. Otherwise,
      # just return the entry as a hash
      # entry - Systemd::JournalEntry or Hash
      # Return value is always a Hash
      def mutate_entry(entry)
        return @mutator.run(entry) unless @mutator.nil?
        entry.to_h
      end
    end
  end
end
