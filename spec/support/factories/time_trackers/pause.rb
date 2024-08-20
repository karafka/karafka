# frozen_string_literal: true

FactoryBot.define do
  factory :time_trackers_pause, class: 'Karafka::TimeTrackers::Pause' do
    # Broken in factory bot when using Ruby 3.0
    timeout { 500 } if RUBY_VERSION >= '3.1'

    max_timeout { 1_000 }
    exponential_backoff { true }

    skip_create

    initialize_with do
      if RUBY_VERSION >= '3.1'
        new(timeout: timeout, max_timeout: max_timeout, exponential_backoff: exponential_backoff)
      else
        new(timeout: 500, max_timeout: max_timeout, exponential_backoff: exponential_backoff)
      end
    end
  end
end
