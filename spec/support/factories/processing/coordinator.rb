# frozen_string_literal: true

FactoryBot.define do
  factory :processing_coordinator, class: 'Karafka::Processing::Coordinator' do
    skip_create

    pause_tracker { build(:time_trackers_pause) }
    seek_offset { nil }

    initialize_with do
      coordinator = new(pause_tracker)
      coordinator.increment
      coordinator.seek_offset = seek_offset
      coordinator
    end
  end

  factory :processing_coordinator_pro, class: 'Karafka::Pro::Processing::Coordinator' do
    skip_create

    pause_tracker { build(:time_trackers_pause) }
    seek_offset { nil }

    initialize_with do
      coordinator = new(pause_tracker)
      coordinator.increment
      coordinator.seek_offset = seek_offset
      coordinator
    end
  end
end
