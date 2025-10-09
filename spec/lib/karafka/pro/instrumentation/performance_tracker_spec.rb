# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  let(:tracker) { Karafka::Pro::Instrumentation::PerformanceTracker.instance }

  let(:m_class) { Karafka::Messages::Messages }
  let(:c_class) { Karafka::BaseConsumer }

  describe '#processing_time_p95 and #on_consumer_consumed' do
    let(:p95) { tracker.processing_time_p95(topic, partition) }
    let(:event) { Karafka::Core::Monitoring::Event.new(rand.to_s, payload) }

    context 'when given topic does not exist' do
      let(:topic) { SecureRandom.hex(6) }
      let(:partition) { 0 }

      it { expect(p95).to eq(0) }
    end

    context 'when topic exists but not the partition' do
      let(:message) { build(:messages_message, metadata: build(:messages_metadata)) }
      let(:messages) { instance_double(m_class, metadata: message.metadata, size: 12) }
      let(:payload) { { caller: instance_double(c_class, messages: messages), time: 200 } }
      let(:topic) { message.metadata.topic }
      let(:partition) { 1 }

      before { tracker.on_consumer_consumed(event) }

      it { expect(p95).to eq(0) }
    end

    context 'when topic and partition exist' do
      context 'when there is only one value' do
        let(:message) { build(:messages_message, metadata: build(:messages_metadata)) }
        let(:messages) { instance_double(m_class, metadata: message.metadata, size: 1) }
        let(:payload) { { caller: instance_double(c_class, messages: messages), time: 20 } }
        let(:topic) { message.metadata.topic }
        let(:partition) { 0 }

        before { tracker.on_consumer_consumed(event) }

        it { expect(p95).to eq(20) }
      end

      context 'when there are more values for a give partition' do
        let(:message) { build(:messages_message, metadata: build(:messages_metadata)) }
        let(:messages) { instance_double(m_class, metadata: message.metadata, size: 1) }
        let(:payload) { { caller: instance_double(c_class, messages: messages), time: 20 } }
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

  describe 'events mapping' do
    it { expect(NotificationsChecker.valid?(tracker)).to be(true) }
  end
end
