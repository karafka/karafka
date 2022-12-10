# frozen_string_literal: true

FactoryBot.define do
  factory :processing_executor, class: 'Karafka::Processing::Executor' do
    skip_create

    group_id { SecureRandom.hex(6) }
    client { nil }
    topic { build(:routing_topic) }

    initialize_with do
      new(group_id, client, topic)
    end
  end
end
