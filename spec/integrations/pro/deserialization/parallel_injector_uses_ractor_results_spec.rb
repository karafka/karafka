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

# Regression for a bug where `Karafka::Pro::Processing::Strategies::Default#handle_before_consume`
# overrode the OSS version without re-retrieving the parallel deserialization Future. Results
# produced by the Ractor pool were silently discarded and consumers fell back to inline
# deserialization, paying the Ractor shipping cost while never actually parallelizing anything.
#
# We detect the bug at runtime by having the deserializer tag its output with the Ractor it ran
# in. In Ractor workers `Ractor.current != Ractor.main`, so it returns `"ractor"`. When the bug
# is present, `.payload` falls back to inline deserialization on the worker thread (still the
# main Ractor), so the tag comes back as `"main"`.

setup_karafka do |config|
  config.concurrency = 1
  config.deserializing.parallel.active = true
  config.deserializing.parallel.concurrency = 2
  # Dispatch every batch to the pool, regardless of size
  config.deserializing.parallel.min_payloads = 1
end

# Ractor-shareable deserializer. Must have no mutable state so it can be frozen and
# shipped to the Ractor pool via `work.freeze` in `Parallel::Pool#dispatch_async`.
class RactorTaggingDeserializer
  def call(message)
    source = (Ractor.current == Ractor.main) ? "main" : "ractor"
    { "source" => source, "bytes" => message.raw_payload.bytesize }
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:sources] << message.payload["source"]
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    deserializing(
      payload: RactorTaggingDeserializer.new.freeze,
      parallel: true
    )
  end
end

produce_many(DT.topic, Array.new(100) { |i| i.to_s })

start_karafka_and_wait_until do
  DT[:sources].size >= 100
end

# Every message must have been deserialized by a Ractor worker. A single "main" tag here
# means the parallel deserialization result was dropped and the message fell back to inline
# deserialization — exactly the symptom of the Pro `handle_before_consume` regression.
assert_equal 100, DT[:sources].size
assert(
  DT[:sources].all? { |s| s == "ractor" },
  "Expected every payload to be deserialized in a Ractor worker but saw " \
    "#{DT[:sources].tally.inspect}. This means the Pro strategy fell back to inline " \
    "deserialization instead of using the Ractor pool's results."
)
