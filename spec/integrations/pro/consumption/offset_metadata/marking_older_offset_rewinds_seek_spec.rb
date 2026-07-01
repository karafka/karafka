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

# Pro-strategy counterpart of the OSS `marking_older_offset_rewinds_seek` spec. The
# `manual_offset_management` feature routes this topic through the Pro strategy, so this guards the
# Pro `Strategies::Default#mark_as_consumed!` guard (which is a separate copy of the same logic).
#
# Marking an offset older than the one already marked is supported and intentional (#2432 - "allow
# marking older offsets to support advanced rewind capabilities"): it rewinds the in-memory seek
# offset, so the error-triggered seek-back reprocesses from the older offset instead of only ever
# moving forward. Only re-marking the exact current offset is ignored (to protect stored metadata).

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:offsets] << message.offset }

    # Rewind only once; after the retry we let processing settle
    return if DT.key?(:rewound)

    mark_as_consumed!(messages.last)

    # Mark an offset older than the one we just marked - this must rewind the seek offset
    older = messages.find { |message| message.offset == 4 }
    mark_as_consumed!(older)

    DT[:rewound] = true

    # Forces a pause and a seek back to the (now rewound) seek offset
    raise StandardError
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management(true)
  end
end

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[:offsets].size >= 15
end

# First pass processed the whole batch
assert_equal((0..9).to_a, DT[:offsets].first(10))

# Marking offset 4 rewound the seek offset to 5, so the error retry reprocessed 5..9
assert_equal((5..9).to_a, DT[:offsets][10, 5])
