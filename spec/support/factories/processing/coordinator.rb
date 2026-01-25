# frozen_string_literal: true

FactoryBot.define do
  factory :processing_coordinator, class: "Karafka::Processing::Coordinator" do
    skip_create

    topic { build(:routing_topic) }
    partition { 0 }
    pause_tracker { build(:time_trackers_pause) }
    seek_offset { nil }
    job_type { :consume }

    initialize_with do
      coordinator = new(topic, partition, pause_tracker)
      coordinator.increment(job_type)
      coordinator.seek_offset = seek_offset
      coordinator
    end
  end

  factory :processing_coordinator_pro, class: "Karafka::Pro::Processing::Coordinator" do
    skip_create

    topic { build(:routing_topic) }
    partition { 0 }
    pause_tracker { build(:time_trackers_pause) }
    seek_offset { nil }
    job_type { :consume }

    initialize_with do
      coordinator = new(topic, partition, pause_tracker)
      coordinator.increment(job_type)
      coordinator.seek_offset = seek_offset
      coordinator
    end
  end
end
