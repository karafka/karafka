# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# We should be able to use cleaning functionality even when external libraries
# prepend modules to Messages#each (like DataDog tracing)
#
# This tests the fix for: https://github.com/DataDog/dd-trace-rb/issues/4867

setup_karafka

# Simulate external library instrumentation (like DataDog)
module ExternalInstrumentation
  def each(clean: false, &_block)
    super(clean: clean) do |message|
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
    per_message_clean_status = []

    messages.each(clean: true) do |message|
      # Process the message
      message.payload

      # Verify message gets cleaned after processing
      DT[1] << message.offset

      # Critical test: Check if previously processed messages are already cleaned
      # When processing message at offset 1, message at offset 0 should be cleaned
      # When processing message at offset 2, messages at offsets 0,1 should be cleaned
      if message.offset > 0
        first_message = messages.to_a.first
        per_message_clean_status << first_message.cleaned?
      end
    end

    # Store instrumentation calls for verification
    DT[0] = DT[:tracker].dup

    # Store per-message cleaning verification
    DT[4] = per_message_clean_status

    # Verify all messages were cleaned using both methods
    cleaned_count = 0
    cleaned_flags = []

    messages.to_a.each do |message|
      # Check cleaned? flag (more direct)
      cleaned_flags << message.cleaned?

      # Also verify by attempting to access payload (existing method)
      begin
        message.payload
      rescue Karafka::Pro::Cleaner::Errors::MessageCleanedError
        cleaned_count += 1
      end
    end

    DT[2] = cleaned_count
    DT[3] = cleaned_flags
  end
end

draw_routes(Consumer)

elements = DT.uuids(5).map { |val| { val: val }.to_json }
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[1]&.size == 5
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
assert DT[3] == [true, true, true, true, true]

# Critical: Verify cleaning happened after each message, not after all
# When processing messages 1,2,3,4 the first message (offset 0) should already be cleaned
assert DT[4] == [true, true, true, true]
