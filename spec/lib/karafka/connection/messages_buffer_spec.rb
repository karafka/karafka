# frozen_string_literal: true

RSpec.describe_current do
  subject(:buffer) { described_class.new }

  describe '#<<, #size and #each' do
    context 'when there are no messages' do
      it { expect(buffer.size).to eq(0) }

      it 'expect not to yield anything' do
        expect { |block| buffer.each(&block) }.not_to yield_control
      end
    end

    context 'when there is a message' do
      let(:message) { build(:messages_message) }

      before { buffer << message }

      it { expect(buffer.size).to eq(1) }

      it 'expect to yield with messages from this topic partition' do
        expect { |block| buffer.each(&block) }
          .to yield_with_args(message.topic, message.partition, [message])
      end
    end

    context 'when there are messages from same partitions of the same topic' do
      let(:message) { build(:messages_message) }

      before { 3.times { buffer << message } }

      it { expect(buffer.size).to eq(3) }

      it 'expect to yield with messages from this topic partition' do
        expect { |block| buffer.each(&block) }
          .to yield_with_args(message.topic, message.partition, [message, message, message])
      end
    end

    context 'when there are messages from different partitions of the same topic' do
      let(:message1) do
        build(:messages_message, metadata: build(:messages_metadata, partition: 1))
      end
      let(:message2) do
        build(:messages_message, metadata: build(:messages_metadata, partition: 2))
      end

      before do
        buffer << message1
        buffer << message2
      end

      it { expect(buffer.size).to eq(2) }

      it 'expect to yield with messages from given partitions separately' do
        expect { |block| buffer.each(&block) }
          .to yield_successive_args(
            [message1.topic, message1.partition, [message1]],
            [message2.topic, message2.partition, [message2]]
          )
      end
    end

    context 'when there are messages from same partitions of different topics' do
      let(:message1) do
        build(:messages_message, metadata: build(:messages_metadata, topic: 1))
      end
      let(:message2) do
        build(:messages_message, metadata: build(:messages_metadata, topic: 2))
      end

      before do
        buffer << message1
        buffer << message2
      end

      it { expect(buffer.size).to eq(2) }

      it 'expect to yield with messages from given topics partitions separately' do
        expect { |block| buffer.each(&block) }
          .to yield_successive_args(
            [message1.topic, message1.partition, [message1]],
            [message2.topic, message2.partition, [message2]]
          )
      end
    end
  end

  describe '#clear' do
    before { buffer << build(:messages_message) }

    it { expect { buffer.clear }.to change(buffer, :size).from(1).to(0) }

    it 'expect not to have anything to process after cleaning' do
      buffer.clear
      expect { |block| buffer.each(&block) }.not_to yield_control
    end
  end
end
