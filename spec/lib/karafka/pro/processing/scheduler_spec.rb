# frozen_string_literal: true

require 'karafka/pro/performance_tracker'
require 'karafka/pro/processing/scheduler'

RSpec.describe_current do
  let(:queue) { [] }

  describe '#schedule_consumption' do
    subject(:schedule) { described_class.new.schedule_consumption(queue, jobs_array) }

    4.times { |i| let("message#{i}") { build(:messages_message) } }

    let(:tracker) { Karafka::Pro::PerformanceTracker.instance }
    let(:jobs_array) { [] }

    context 'when there are no metrics on any of the topics data' do
      before do
        4.times do |i|
          jobs_array << Karafka::Processing::Jobs::Consume.new(
            nil,
            [public_send("message#{i}")],
            nil
          )
        end

        schedule
      end

      # @note This is an edge case for first batch. After that we will get measurements, so we
      #   don't have to worry. "Ignoring" this non-optimal first case simplifies the codebase
      it { expect(queue[0]).to eq(jobs_array[3]) }
      it { expect(queue[1]).to eq(jobs_array[2]) }
      it { expect(queue[2]).to eq(jobs_array[1]) }
      it { expect(queue[3]).to eq(jobs_array[0]) }
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
          Karafka::Core::Monitoring::Event.new(rand.to_s, public_send("payload#{i}"))
        end
      end

      before do
        4.times do |i|
          jobs_array << Karafka::Processing::Jobs::Consume.new(
            nil,
            [public_send("message#{i}")],
            nil
          )
          tracker.on_consumer_consumed(public_send("event#{i}"))
        end

        schedule
      end

      it { expect(queue[0]).to eq(jobs_array[3]) }
      it { expect(queue[1]).to eq(jobs_array[1]) }
      it { expect(queue[2]).to eq(jobs_array[2]) }
      it { expect(queue[3]).to eq(jobs_array[0]) }
    end
  end
end
