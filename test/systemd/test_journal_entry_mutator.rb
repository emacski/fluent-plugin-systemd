# frozen_string_literal: true
require_relative "../helper"
require "json"
require "systemd/journal"
require "systemd/journal_entry_mutator"

class EntryTestData # rubocop:disable ClassLength
  # `Systemd::Journal::Entry` to test with
  ENTRY = lambda {
    j = Systemd::Journal.new(path: "test/fixture")
    j.wait(0)
    j.seek(:tail)
    j.move(-2)
    j.move_next
    j.current_entry
  }[].freeze

  # field map used for tests
  FIELD_MAP = {
    "_PID"     => %w[msg _PID],
    "MESSAGE"  => "msg",
    "_COMM"    => "_EXE",
    "_CMDLINE" => "command",
  }.freeze

  # string json form of `FIELD_MAP`
  FIELD_MAP_JSON = JSON.generate(FIELD_MAP).freeze

  # expected entry mutation results
  EXPECTED = {
    no_transform: {
      "_UID" => "0",
      "_GID" => "0",
      "_BOOT_ID" => "4737ffc504774b3ba67020bc947f1bc0",
      "_MACHINE_ID" => "bb9d0a52a41243829ecd729b40ac0bce",
      "_HOSTNAME" => "arch",
      "PRIORITY" => "5",
      "_TRANSPORT" => "syslog",
      "SYSLOG_FACILITY" => "10",
      "SYSLOG_IDENTIFIER" => "login",
      "_PID" => "141",
      "_COMM" => "login",
      "_EXE" => "/bin/login",
      "_AUDIT_SESSION" => "1",
      "_AUDIT_LOGINUID" => "0",
      "MESSAGE" => "ROOT LOGIN ON tty1",
      "_CMDLINE" => "login -- root      ",
      "_SYSTEMD_CGROUP" => "/user/root/1",
      "_SYSTEMD_SESSION" => "1",
      "_SYSTEMD_OWNER_UID" => "0",
      "_SOURCE_REALTIME_TIMESTAMP" => "1364519243563178",
    },
    fields_strip_underscores: {
      "UID" => "0",
      "GID" => "0",
      "BOOT_ID" => "4737ffc504774b3ba67020bc947f1bc0",
      "MACHINE_ID" => "bb9d0a52a41243829ecd729b40ac0bce",
      "HOSTNAME" => "arch",
      "PRIORITY" => "5",
      "TRANSPORT" => "syslog",
      "SYSLOG_FACILITY" => "10",
      "SYSLOG_IDENTIFIER" => "login",
      "PID" => "141",
      "COMM" => "login",
      "EXE" => "/bin/login",
      "AUDIT_SESSION" => "1",
      "AUDIT_LOGINUID" => "0",
      "MESSAGE" => "ROOT LOGIN ON tty1",
      "CMDLINE" => "login -- root      ",
      "SYSTEMD_CGROUP" => "/user/root/1",
      "SYSTEMD_SESSION" => "1",
      "SYSTEMD_OWNER_UID" => "0",
      "SOURCE_REALTIME_TIMESTAMP" => "1364519243563178",
    },
    fields_lowercase: {
      "_uid" => "0",
      "_gid" => "0",
      "_boot_id" => "4737ffc504774b3ba67020bc947f1bc0",
      "_machine_id" => "bb9d0a52a41243829ecd729b40ac0bce",
      "_hostname" => "arch",
      "priority" => "5",
      "_transport" => "syslog",
      "syslog_facility" => "10",
      "syslog_identifier" => "login",
      "_pid" => "141",
      "_comm" => "login",
      "_exe" => "/bin/login",
      "_audit_session" => "1",
      "_audit_loginuid" => "0",
      "message" => "ROOT LOGIN ON tty1",
      "_cmdline" => "login -- root      ",
      "_systemd_cgroup" => "/user/root/1",
      "_systemd_session" => "1",
      "_systemd_owner_uid" => "0",
      "_source_realtime_timestamp" => "1364519243563178",
    },
    field_map: {
      "_UID" => "0",
      "_GID" => "0",
      "_BOOT_ID" => "4737ffc504774b3ba67020bc947f1bc0",
      "_MACHINE_ID" => "bb9d0a52a41243829ecd729b40ac0bce",
      "_HOSTNAME" => "arch",
      "PRIORITY" => "5",
      "_TRANSPORT" => "syslog",
      "SYSLOG_FACILITY" => "10",
      "SYSLOG_IDENTIFIER" => "login",
      "_PID" => "141",
      "_EXE" => "/bin/login login",
      "_AUDIT_SESSION" => "1",
      "_AUDIT_LOGINUID" => "0",
      "msg" => "141 ROOT LOGIN ON tty1",
      "command" => "login -- root      ",
      "_SYSTEMD_CGROUP" => "/user/root/1",
      "_SYSTEMD_SESSION" => "1",
      "_SYSTEMD_OWNER_UID" => "0",
      "_SOURCE_REALTIME_TIMESTAMP" => "1364519243563178",
    },
    field_map_strict: {
      "_PID" => "141",
      "_EXE" => "login",
      "msg" => "141 ROOT LOGIN ON tty1",
      "command" => "login -- root      ",
    },
  }.freeze
end

class JournalEntryMutatorTest < Test::Unit::TestCase
  # option validation test data in the form:
  # { test_name: option_hash }
  @validation_tests = {
    bad_fmap_opt_1: { field_map: { 1 => "one" } },
    bad_fmap_opt_2: { field_map: { "one" => 1 } },
    bad_fmap_opt_3: { field_map: { "One" => ["one", 1] } },
    bad_fmap_strict_opt: { field_map_strict: 1 },
    bad_underscores_opt: { fields_strip_underscores: 1 },
    bad_lowercase_opt: { fields_lowercase: 1 },
  }
  # mutate test data in the form:
  # { test_name: [transform_params, expected_entry], ... }
  @mutate_tests = {
    fields_strip_underscores: [
      { fields_strip_underscores: true },
      EntryTestData::EXPECTED[:fields_strip_underscores],
    ],
    fields_lowercase: [
      { fields_lowercase: true },
      EntryTestData::EXPECTED[:fields_lowercase],
    ],
    field_map: [
      { field_map: EntryTestData::FIELD_MAP },
      EntryTestData::EXPECTED[:field_map],
    ],
    field_map_strict: [
      { field_map: EntryTestData::FIELD_MAP, field_map_strict: true },
      EntryTestData::EXPECTED[:field_map_strict],
    ],
  }

  data(@validation_tests)
  def test_validation(opt)
    assert_raise Systemd::JournalEntryMutator::OptionError do
      Systemd::JournalEntryMutator.new(**opt)
    end
  end

  # tests using Systemd::JournalEntry
  data(@mutate_tests)
  def test_mutate_with_journal_entry(data)
    options, expected = data
    f = Systemd::JournalEntryMutator.new(**options)
    filtered = f.run(EntryTestData::ENTRY)
    assert_equal(expected, filtered)
  end

  # tests using an entry hash
  data(@mutate_tests)
  def test_mutate_with_hash_entry(data)
    options, expected = data
    f = Systemd::JournalEntryMutator.new(**options)
    filtered = f.run(EntryTestData::ENTRY.to_h)
    assert_equal(expected, filtered)
  end
end
