# frozen_string_literal: true

FactoryBot.define do
  factory :processing_executor, class: 'Karafka::Processing::Executor' do
    skip_create

    group_id { SecureRandom.uuid }
    client { nil }
    topic { build(:routing_topic) }
    pause { build(:time_trackers_pause) }

    initialize_with do
      new(group_id, client, topic, pause)
    end
  end
end
