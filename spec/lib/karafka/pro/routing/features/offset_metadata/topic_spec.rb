# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe '#offset_metadata' do
    context 'when we use offset_metadata without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.offset_metadata.active?).to eq(true)
        expect(topic.offset_metadata.deserializer).not_to be_nil
      end
    end

    context 'when we use offset_metadata multiple times with different values' do
      it 'expect to use proper active status' do
        topic.offset_metadata(deserializer: 1)
        topic.offset_metadata(deserializer: 2)
        expect(topic.offset_metadata.active?).to eq(true)
        expect(topic.offset_metadata.deserializer).to eq(1)
      end
    end
  end

  describe '#offset_metadata?' do
    it { expect(topic.offset_metadata?).to eq(true) }
  end

  describe '#to_h' do
    it { expect(topic.to_h[:offset_metadata]).to eq(topic.offset_metadata.to_h) }
  end
end
