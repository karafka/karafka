# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# A scheduled message stamped with an older (compatible) schema version must be accepted and
# dispatched also when the version segments differ in digit count. Schema versions are semver,
# so "1.2.0" is older than "1.10.0" while being lexicographically greater. Prior to the fix,
# versions were compared as strings and such a message was rejected as incompatible, breaking
# all older scheduled messages after a consumer upgrade past a two-digit schema segment.

setup_karafka(allow_errors: true)

class Listener
  def on_error_occurred(event)
    DT[:errors] << event[:error]
  end
end

Karafka.monitor.subscribe(Listener.new)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:dispatched] << message.raw_payload }
  end
end

draw_routes do
  scheduled_messages(DT.topics[0])

  topic DT.topics[1] do
    consumer Consumer
  end
end

# Simulate a message produced by an older library version with a semver-lower but
# lexicographically greater schema version than the consumer's
Karafka::Pro::ScheduledMessages.send(:remove_const, :SCHEMA_VERSION)
Karafka::Pro::ScheduledMessages.const_set(:SCHEMA_VERSION, "1.2.0")

proxy = Karafka::Pro::ScheduledMessages.schedule(
  message: { topic: DT.topics[1], payload: "older-schema-payload" },
  epoch: Time.now.to_i + 2,
  envelope: { topic: DT.topics[0], partition: 0 }
)

Karafka.producer.produce_sync(proxy)

# Simulate the consumer running a newer library version with a two-digit schema segment
Karafka::Pro::ScheduledMessages.send(:remove_const, :SCHEMA_VERSION)
Karafka::Pro::ScheduledMessages.const_set(:SCHEMA_VERSION, "1.10.0")

incompatible = lambda do
  DT[:errors].any? do |error|
    error.is_a?(Karafka::Pro::ScheduledMessages::Errors::IncompatibleSchemaError)
  end
end

start_karafka_and_wait_until do
  DT.key?(:dispatched) || incompatible.call
end

assert_equal(
  false,
  incompatible.call,
  "older compatible schema version was rejected as incompatible (string comparison)"
)

assert_equal ["older-schema-payload"], DT[:dispatched]
