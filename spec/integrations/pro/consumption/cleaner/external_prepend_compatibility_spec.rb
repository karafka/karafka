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
# We should be able to use cleaning functionality even when external libraries
# prepend modules to Messages#each (like DataDog tracing)
#
# This tests the fix for: https://github.com/DataDog/dd-trace-rb/issues/4867

setup_karafka

# Simulate external library instrumentation (like DataDog)
module ExternalInstrumentation
  def each(clean: false, &_block)
    super do |message|
      DT[:tracker] << "start_#{message.offset}"
      yield(message)
      DT[:tracker] << "end_#{message.offset}"
    end
  end
end

# Prepend external instrumentation before Karafka processes messages
Karafka::Messages::Messages.prepend(ExternalInstrumentation)

class Consumer < Karafka::BaseConsumer
  def consume
    # Test that external instrumentation works with clean: true
    # AND that cleaning happens after each message, not after all
    messages.each(clean: true) do |message|
      # Process the message
      message.payload
      # Verify message gets cleaned after processing
      DT[1] << message.offset

      # Check if messages in current batch get cleaned as we process them
      # Only check within the current batch, not across batches
      messages.to_a.each_with_index do |batch_message, _idx|
        # If we've already processed this message in this batch, it should be cleaned
        if DT[1].include?(batch_message.offset) && batch_message.offset != message.offset
          DT[4] ||= []
          DT[4] << batch_message.cleaned?
        end
      end
    end

    # Store instrumentation calls for verification (append, don't replace)
    DT[0] ||= []
    DT[0].concat(DT[:tracker].dup)
    DT[:tracker].clear

    # Verify all messages in current batch were cleaned
    @cleaned_count ||= 0
    @cleaned_flags ||= []

    messages.to_a.each do |message|
      # Check cleaned? flag
      @cleaned_flags << message.cleaned?
      # Also verify by attempting to access payload
      begin
        message.payload
      rescue Karafka::Pro::Cleaner::Errors::MessageCleanedError
        @cleaned_count += 1
      end
    end

    # Store cumulative counts across all batches
    DT[2] = @cleaned_count
    DT[3] = @cleaned_flags
  end
end

draw_routes(Consumer)
elements = DT.uuids(5).map { |val| { val: val }.to_json }
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[1].size == 5
end

# Verify external instrumentation was called
instrumentation_calls = DT[0]
assert instrumentation_calls.size >= 10 # start + end for each of 5 messages

# Verify instrumentation wrapped each message
(0..4).each do |offset|
  assert instrumentation_calls.include?("start_#{offset}")
  assert instrumentation_calls.include?("end_#{offset}")
end

# Verify all messages were cleaned (by exception method)
assert DT[2] == 5

# Verify all messages were cleaned (by cleaned? flag)
assert DT[3].all?(true)
assert DT[3].size == 5

# Verify cleaning happened after each message within batches
# Only check if we had multi-message batches
if DT[4] && DT[4].any?
  assert DT[4].all?(true), "Some messages weren't cleaned after processing"
end
