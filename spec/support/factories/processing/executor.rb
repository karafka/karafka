# frozen_string_literal: true

FactoryBot.define do
  factory :processing_executor, class: 'Karafka::Processing::Executor' do
    skip_create

    group_id { SecureRandom.hex(6) }
    client { nil }
    coordinator { build(:processing_coordinator) }

    initialize_with do
      new(group_id, client, coordinator)
    end
  end
end
