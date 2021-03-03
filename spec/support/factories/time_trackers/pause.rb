# frozen_string_literal: true

FactoryBot.define do
  factory :time_trackers_pause, class: 'Karafka::TimeTrackers::Pause' do
    timeout { 500 }
    max_timeout { 1_000 }
    exponential_backoff { true }

    skip_create

    initialize_with do
      new(timeout: timeout, max_timeout: max_timeout, exponential_backoff: exponential_backoff)
    end
  end
end
