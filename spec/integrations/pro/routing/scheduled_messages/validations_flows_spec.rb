# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When providing invalid config details for scheduled messages, validation should kick in.

begin
  setup_karafka do |config|
    config.scheduled_messages.flush_batch_size = -1
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  guarded = true
  error = e
end

assert guarded

assert_equal(
  error.message,
  { 'config.scheduled_messages.flush_batch_size': 'needs to be an integer bigger than 0' }.to_s
)
