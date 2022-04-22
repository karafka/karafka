# frozen_string_literal: true

RSpec.describe_current do
  subject(:buffer) { described_class.new }

  describe '#<< and #size' do
    context 'when there are no messages' do
      it { expect(buffer.size).to eq(0) }
    end

    context 'when there is a message' do
      let(:message) { build(:messages_message) }

      before { buffer << message }

      it { expect(buffer.size).to eq(1) }
    end

    context 'when there are messages from same partitions of the same topic' do
      let(:message) { build(:messages_message) }

      before { 3.times { buffer << message } }

      it { expect(buffer.size).to eq(3) }
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
    end
  end

  describe '#clear' do
    before { buffer << build(:messages_message) }

    it { expect { buffer.clear }.to change(buffer, :size).from(1).to(0) }
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
    end
  end
end
