# frozen_string_literal: true

require 'karafka/pro/performance_tracker'
require 'karafka/pro/scheduler'

RSpec.describe_current do
  subject(:scheduled_order) do
    scheduler = Karafka::Pro::Scheduler.new
    ordered = []

    scheduler.call(jobs_array) do |job|
      ordered << job
    end

    ordered
  end

  4.times { |i| let("message#{i}") { build(:messages_message) } }

  let(:tracker) { Karafka::Pro::PerformanceTracker.instance }
  let(:jobs_array) { [] }

  context 'when there are no metrics on any of the topics data' do
    before do
      4.times do |i|
        jobs_array << Karafka::Processing::Jobs::Consume.new(nil, [public_send("message#{i}")])
      end
    end

    # @note This is an edge case for first batch. After that we will get measurements, so we don't
    #   have to worry. "Ignoring" this non-optimal first case simplifies the codebase
    it { expect(scheduled_order[0]).to eq(jobs_array[3]) }
    it { expect(scheduled_order[1]).to eq(jobs_array[2]) }
    it { expect(scheduled_order[2]).to eq(jobs_array[1]) }
    it { expect(scheduled_order[3]).to eq(jobs_array[0]) }
  end

  context 'when metrics on the computation cost for messages from topics are present' do
    times = [5, 20, 7, 100]

    4.times do |i|
      let("messages#{i}") do
        OpenStruct.new(metadata: public_send("message#{i}").metadata, count: 1)
      end

      let("payload#{i}") do
        { caller: OpenStruct.new(messages: public_send("messages#{i}")), time: times[i] }
      end

      let("event#{i}") do
        Dry::Events::Event.new(rand.to_s, public_send("payload#{i}"))
      end
    end

    before do
      4.times do |i|
        jobs_array << Karafka::Processing::Jobs::Consume.new(nil, [public_send("message#{i}")])
        tracker.on_consumer_consumed(public_send("event#{i}"))
      end
    end

    it { expect(scheduled_order[0]).to eq(jobs_array[3]) }
    it { expect(scheduled_order[1]).to eq(jobs_array[1]) }
    it { expect(scheduled_order[2]).to eq(jobs_array[2]) }
    it { expect(scheduled_order[3]).to eq(jobs_array[0]) }
  end
end
