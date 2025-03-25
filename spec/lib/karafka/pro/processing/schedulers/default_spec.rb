# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:scheduler) { described_class.new(queue) }

  let(:queue) { [] }
  let(:jobs_array) { [] }

  describe '#schedule_consumption' do
    subject(:schedule) { scheduler.on_schedule_consumption(jobs_array) }

    4.times { |i| let("message#{i}") { build(:messages_message) } }

    let(:tracker) { Karafka::Pro::Instrumentation::PerformanceTracker.instance }
    let(:jobs_array) { [] }

    context 'when there are no metrics on any of the topics data' do
      before do
        4.times do |i|
          jobs_array << Karafka::Processing::Jobs::Consume.new(
            nil,
            [public_send("message#{i}")]
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
          OpenStruct.new(metadata: public_send("message#{i}").metadata, size: 1)
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
            [public_send("message#{i}")]
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

    context 'when metrics on the computation cost are present with other jobs' do
      times = [5, 20, 7, 100]

      4.times do |i|
        let("messages#{i}") do
          OpenStruct.new(metadata: public_send("message#{i}").metadata, size: 1)
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
            [public_send("message#{i}")]
          )
          tracker.on_consumer_consumed(public_send("event#{i}"))
        end

        jobs_array << Karafka::Processing::Jobs::Idle.new(nil)

        schedule
      end

      it { expect(queue[0]).to eq(jobs_array[4]) }
      it { expect(queue[1]).to eq(jobs_array[3]) }
      it { expect(queue[2]).to eq(jobs_array[1]) }
      it { expect(queue[3]).to eq(jobs_array[2]) }
      it { expect(queue[4]).to eq(jobs_array[0]) }
    end
  end

  %i[
    on_schedule_revocation
    on_schedule_shutdown
    on_schedule_idle
    on_schedule_periodic
  ].each do |action|
    describe "##{action}" do
      subject(:schedule) { scheduler.public_send(action, jobs_array) }

      context 'when there are no messages' do
        it 'expect not to schedule anything' do
          schedule
          expect(queue).to be_empty
        end
      end

      context 'when there are jobs' do
        let(:jobs_array) do
          [
            Karafka::Processing::Jobs::Consume.new(nil, []),
            Karafka::Processing::Jobs::Consume.new(nil, []),
            Karafka::Processing::Jobs::Consume.new(nil, []),
            Karafka::Processing::Jobs::Consume.new(nil, [])
          ]
        end

        it 'expect to schedule in the fifo order' do
          schedule
          expect(queue).to eq(jobs_array)
        end
      end
    end
  end

  describe '#manage' do
    it { expect { scheduler.on_manage }.not_to raise_error }
  end

  describe '#clear' do
    it { expect { scheduler.on_clear(rand.to_s) }.not_to raise_error }
  end
end
