# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When providing invalid config details for scheduled messages, validation should kick in.

become_pro!

begin
  Karafka::App.setup do |config|
    config.kafka = { 'bootstrap.servers': '127.0.0.1:9092' }
    config.recurring_tasks.interval = -1
  end
rescue Karafka::Errors::InvalidConfigurationError => e
  guarded = true
  error = e
end

assert guarded

assert_equal(
  error.message,
  { 'config.recurring_tasks.interval': 'needs to be equal or more than 1000 and an integer' }.to_s
)
