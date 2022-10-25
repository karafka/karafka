# frozen_string_literal: true

RSpec.describe_current do
  let(:tracker) { Karafka::Pro::PerformanceTracker.instance }

  describe '#processing_time_p95 and #on_consumer_consumed' do
    let(:p95) { tracker.processing_time_p95(topic, partition) }
    let(:event) { Karafka::Core::Monitoring::Event.new(rand.to_s, payload) }

    context 'when given topic does not exist' do
      let(:topic) { SecureRandom.uuid }
      let(:partition) { 0 }

      it { expect(p95).to eq(0) }
    end

    context 'when topic exists but not the partition' do
      let(:message) { build(:messages_message, metadata: build(:messages_metadata)) }
      let(:messages) { OpenStruct.new(metadata: message.metadata, count: 12) }
      let(:payload) { { caller: OpenStruct.new(messages: messages), time: 200 } }
      let(:topic) { message.metadata.topic }
      let(:partition) { 1 }

      before { tracker.on_consumer_consumed(event) }

      it { expect(p95).to eq(0) }
    end

    context 'when topic and partition exist' do
      context 'when there is only one value' do
        let(:message) { build(:messages_message, metadata: build(:messages_metadata)) }
        let(:messages) { OpenStruct.new(metadata: message.metadata, count: 1) }
        let(:payload) { { caller: OpenStruct.new(messages: messages), time: 20 } }
        let(:topic) { message.metadata.topic }
        let(:partition) { 0 }

        before { tracker.on_consumer_consumed(event) }

        it { expect(p95).to eq(20) }
      end

      context 'when there are more values for a give partition' do
        let(:message) { build(:messages_message, metadata: build(:messages_metadata)) }
        let(:messages) { OpenStruct.new(metadata: message.metadata, count: 1) }
        let(:payload) { { caller: OpenStruct.new(messages: messages), time: 20 } }
        let(:topic) { message.metadata.topic }
        let(:partition) { 0 }

        before do
          100.times do |i|
            payload[:time] = i % 10
            tracker.on_consumer_consumed(event)
          end
        end

        it { expect(p95).to eq(9) }
      end
    end
  end
end
