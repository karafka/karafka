# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe '#eofed' do
    context 'when we use eofed without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.eofed.active?).to be(false)
      end
    end

    context 'when we use eofed with active status' do
      it 'expect to use proper active status' do
        topic.eofed(true)
        expect(topic.eofed.active?).to be(true)
      end
    end

    context 'when we use eofed multiple times with different values' do
      it 'expect to use proper active status' do
        topic.eofed(true)
        topic.eofed(false)
        expect(topic.eofed.active?).to be(true)
      end
    end
  end

  describe '#eofed?' do
    context 'when active' do
      before { topic.eofed(true) }

      it { expect(topic.eofed?).to be(true) }
    end

    context 'when not active' do
      before { topic.eofed(false) }

      it { expect(topic.eofed?).to be(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:eofed]).to eq(topic.eofed.to_h) }
  end
end
