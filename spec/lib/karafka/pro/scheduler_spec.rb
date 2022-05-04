# frozen_string_literal: true

require 'karafka/pro/performance_tracker'
require 'karafka/pro/scheduler'

RSpec.describe_current do
  subject(:scheduled_order) do
    scheduler = Karafka::Pro::Scheduler.new
    ordered = []

    scheduler.call(messages_buffer) do |topic, partition, messages, _|
      ordered << [topic, partition, messages]
    end

    ordered
  end

  4.times { |i| let("message#{i}") { build(:messages_message) } }

  let(:tracker) { Karafka::Pro::PerformanceTracker.instance }
  let(:messages_buffer) { Karafka::Connection::MessagesBuffer.new }

  context 'when there are no metrics on any of the topics data' do
    before { 4.times { |i| messages_buffer << public_send("message#{i}") } }

    # @note This is an edge case for first batch. After that we will get measurements, so we don't
    #   have to worry. "Ignoring" this non-optimal first case simplifies the codebase
    it { expect(scheduled_order[0]).to eq([message3.topic, message3.partition, [message3]]) }
    it { expect(scheduled_order[1]).to eq([message2.topic, message2.partition, [message2]]) }
    it { expect(scheduled_order[2]).to eq([message1.topic, message1.partition, [message1]]) }
    it { expect(scheduled_order[3]).to eq([message0.topic, message0.partition, [message0]]) }
  end

  context 'when metrics on the computation cost for messages from topics are present' do
    4.times do |i|
      let("messages#{i}") do
        OpenStruct.new(metadata: public_send("message#{i}").metadata, count: 1)
      end

      let("payload#{i}") do
        { caller: OpenStruct.new(messages: public_send("messages#{i}")), time: i * 100 }
      end

      let("event#{i}") do
        Dry::Events::Event.new(rand.to_s, public_send("payload#{i}"))
      end
    end

    before do
      4.times do |i|
        messages_buffer << public_send("message#{i}")
        tracker.on_consumer_consumed(public_send("event#{i}"))
      end
    end

    it { expect(scheduled_order[0]).to eq([message3.topic, message3.partition, [message3]]) }
    it { expect(scheduled_order[1]).to eq([message2.topic, message2.partition, [message2]]) }
    it { expect(scheduled_order[2]).to eq([message1.topic, message1.partition, [message1]]) }
    it { expect(scheduled_order[3]).to eq([message0.topic, message0.partition, [message0]]) }
  end
end
