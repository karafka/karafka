# frozen_string_literal: true

FactoryBot.define do
  factory :processing_coordinator, class: 'Karafka::Processing::Coordinator' do
    skip_create

    pause_tracker { build(:time_trackers_pause) }

    initialize_with do
      new(pause_tracker).tap(&:increment)
    end
  end

  factory :processing_coordinator_pro, class: 'Karafka::Pro::Processing::Coordinator' do
    skip_create

    pause_tracker { build(:time_trackers_pause) }

    initialize_with do
      new(pause_tracker).tap(&:increment)
    end
  end
end
