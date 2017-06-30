# frozen_string_literal: true
require_relative "../../helper"
require_relative "../../systemd/test_journal_entry_mutator"
require "fluent/config"
require "fluent/plugin/systemd/entry_helpers"

class MutatorFactoryTest < Test::Unit::TestCase
  include Fluent::Test::Helpers
  # valid config test data in the form:
  # { test_name: [option_hash, expected_entry], ... }
  @valid_config_tests = {
    fields_strip_underscores: [
      {
        fields_strip_underscores: true,
      },
      EntryTestData::EXPECTED[:fields_strip_underscores],
    ],
    fields_lowercase: [
      {
        fields_lowercase: true,
      },
      EntryTestData::EXPECTED[:fields_lowercase],
    ],
    field_map: [
      {
        field_map: EntryTestData::FIELD_MAP,
      },
      EntryTestData::EXPECTED[:field_map],
    ],
    field_map_strict: [
      {
        field_map: EntryTestData::FIELD_MAP,
        field_map_strict: true,
      },
      EntryTestData::EXPECTED[:field_map_strict],
    ],
  }
  # invalid config test data in the form:
  # { test_name: option_hash, ... }
  @invalid_config_tests = {
    bad_fmap_opt_1: { field_map: { 1 => "one" } },
    bad_fmap_opt_2: { field_map: { "one" => 1 } },
    bad_fmap_opt_3: { field_map: { "One" => ["one", 1] } },
    bad_fmap_strict_opt: { field_map_strict: 1 },
    bad_underscores_opt: { fields_strip_underscores: 1 },
    bad_lowercase_opt: { fields_lowercase: 1 },
  }

  def create_config_section(conf_hash)
    Fluent::Config::Section.new(config_element("test", "", conf_hash))
  end

  data(@valid_config_tests)
  def test_valid_config_mutator_from_factory(data)
    conf_hash, expected = data
    config = create_config_section(conf_hash)
    m = Fluent::Plugin::SystemdMutatorBuilder.new(config).build
    mutated = m.run(EntryTestData::ENTRY)
    assert_equal(expected, mutated)
  end

  data(@invalid_config_tests)
  def test_invalid_config_mutator_from_factory(conf_hash)
    config = create_config_section(conf_hash)
    assert_raise Fluent::ConfigError do
      Fluent::Plugin::SystemdMutatorBuilder.new(config).build
    end
  end
end

class MutableTest < Test::Unit::TestCase
  require "fluent/plugin/input"
  # dummy input plugin for testing the `Mutable` module
  class MutableTestPlugin < Fluent::Plugin::Input
    include Fluent::Plugin::SystemdMutableEntry
    Fluent::Plugin.register_input("mutable_test_plugin", self)
  end
  # entry test data in the form:
  # { test_name: [plugin_config, expected_entry], ... }
  @entry_tests = {
    no_entry_block: [
      "",
      EntryTestData::EXPECTED[:no_transform],
    ],
    empty_entry_block: [
      %(
        <entry>
        </entry>
      ),
      EntryTestData::EXPECTED[:no_transform],
    ],
    fields_strip_underscores: [
      %(
        <entry>
          fields_strip_underscores true
        </entry>
      ),
      EntryTestData::EXPECTED[:fields_strip_underscores],
    ],
    fields_lowercase: [
      %(
        <entry>
          fields_lowercase true
        </entry>
      ),
      EntryTestData::EXPECTED[:fields_lowercase],
    ],
    field_map: [
      %(
        <entry>
          field_map #{EntryTestData::FIELD_MAP_JSON}
        </entry>
      ),
      EntryTestData::EXPECTED[:field_map],
    ],
    field_map_strict: [
      %(
        <entry>
          field_map #{EntryTestData::FIELD_MAP_JSON}
          field_map_strict true
        </entry>
      ),
      EntryTestData::EXPECTED[:field_map_strict],
    ],
  }

  def create_driver(config)
    Fluent::Test::Driver::Input.new(MutableTestPlugin).configure(config)
  end

  data(@entry_tests)
  def test_valid_config_entry_mutator_mixin(data)
    conf, expect = data
    d = create_driver(conf)
    mutated = d.instance.mutate_entry(EntryTestData::ENTRY)
    assert_equal(expect, mutated)
  end
end
