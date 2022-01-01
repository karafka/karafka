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

  describe '#delete' do
    let(:message1) { build(:messages_message) }
    let(:message2) { build(:messages_message) }

    before { buffer << message1 }

    context 'when given topic does not exist' do
      it 'expect not to remove anything' do
        expect { buffer.delete('na', 0) }.not_to change(buffer, :size)
      end
    end

    context 'when given partition does not exist' do
      it 'expect not to remove anything' do
        expect { buffer.delete(message1.topic, 100) }.not_to change(buffer, :size)
      end
    end

    context 'when given partition exists and is the only one' do
      it 'expect change the buffer size to reflect the change' do
        expect { buffer.delete(message1.topic, 0) }.to change(buffer, :size).by(-1)
      end

      it 'expect to completely remove the topic when no other partitions present' do
        buffer.delete(message1.topic, 0)

        expect { |block| buffer.each(&block) }.not_to yield_control
      end
    end

    context 'when given partition exists and is not the only one' do
      let(:message2) { OpenStruct.new(topic: message1.topic, partition: 1) }

      before { buffer << message2 }

      it 'expect change the buffer size to reflect the change' do
        expect { buffer.delete(message1.topic, 0) }.to change(buffer, :size).by(-1)
      end

      it 'expect to recalculate the buffer size' do
        expect(buffer.size).to eq(2)
        buffer.delete(message1.topic, 0)
        expect(buffer.size).to eq(1)
      end

      it 'expect not to mix the topics' do
        buffer.delete(message1.topic, 0)

        buffer.each do |topic, _, _|
          expect(topic).to eq(message2.topic)
        end
      end

      it 'expect not to mix partitions' do
        buffer.delete(message1.topic, 0)

        buffer.each do |_, partition, _|
          expect(partition).to eq(message2.partition)
        end
      end

      it 'expect not to mix messages in the buffer' do
        buffer.delete(message1.topic, 0)

        buffer.each do |_, _, messages|
          expect(messages).to eq([message2])
        end
      end
    end
  end

  describe 'uniq!' do
    let(:message1) { build(:messages_message) }
    let(:message2) { build(:messages_message) }
    let(:message3) { build(:messages_message) }
    let(:message4) { build(:messages_message) }

    context 'when we have same message twice for the same topic partition' do
      before do
        buffer << message1
        buffer << message2
        buffer << message1
        buffer << message3
        buffer << message4
      end

      it { expect { buffer.uniq! }.to change(buffer, :size).by(-1) }

      it 'expect to maintain messages order' do
        buffer.uniq!

        buffer.each do |_, _, messages|
          expect(messages).to eq([message1, message2, message3, message4])
        end
      end
    end
  end
end
