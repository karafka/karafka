# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Karafka should be able to get offset metadata when non-existing, save it and force refresh
# with defaults and cache on
#
# @note We use mark_as_consumed! to instantly flush

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    return if DT.key?(:after4)

    DT[:before] = offset_metadata

    mark_as_consumed!(messages.last, 'metadata-store1')

    DT[:after1] = offset_metadata
    DT[:after2] = offset_metadata(cache: false)

    # Second write of the same offset will not update the already stored metadata
    # This is expected as offset store with data is immutable
    mark_as_consumed!(messages.last, 'metadata-store2')

    DT[:after3] = offset_metadata
    DT[:after4] = offset_metadata(cache: false)
  end
end

draw_routes(Consumer)

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:after4)
end

assert_equal '', DT[:before]
assert_equal '', DT[:after1]
assert_equal 'metadata-store1', DT[:after2]
assert_equal 'metadata-store1', DT[:after3]
assert_equal 'metadata-store1', DT[:after4]
