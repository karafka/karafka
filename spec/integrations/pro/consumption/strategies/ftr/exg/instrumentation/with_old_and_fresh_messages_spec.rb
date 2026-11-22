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

# When expiring removes old messages, Karafka should instrument `filtering.expired` with the
# number of expired messages and their offsets, and the logger should report it

setup_karafka do |config|
  config.logger = Logger.new(DT[:log] = StringIO.new)
end

Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)

Karafka.monitor.subscribe("filtering.expired") do |event|
  DT[:expired] << event.payload
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    # 1 minute
    expire_in(60_000)
  end
end

old_timestamp = ((Time.now.to_f * 1_000).to_i - 600_000)

produce_many(DT.topic, DT.uuids(5), timestamp: old_timestamp)
produce_many(DT.topic, DT.uuids(5))

start_karafka_and_wait_until do
  DT[:consumed].size >= 5
end

assert_equal (5..9).to_a, DT[:consumed]

expired = DT[:expired]

assert(expired.all? { |payload| payload[:count].positive? })
assert_equal 5, expired.sum { |payload| payload[:count] }
assert_equal 0, expired.map { |payload| payload[:first_offset] }.min
assert_equal 4, expired.map { |payload| payload[:last_offset] }.max
assert_equal [DT.topic], expired.map { |payload| payload[:topic] }.uniq
assert_equal [0], expired.map { |payload| payload[:partition] }.uniq
assert_equal [60_000], expired.map { |payload| payload[:ttl] }.uniq
assert_equal(
  [Karafka::App.routes.first.id],
  expired.map { |payload| payload[:subscription_group].group.id }.uniq
)
assert DT[:log].string.include?("Expired")
assert DT[:log].string.include?("on #{DT.topic}-0")
