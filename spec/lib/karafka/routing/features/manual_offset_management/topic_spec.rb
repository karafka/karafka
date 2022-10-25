# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe '#manual_offset_management' do
    context 'when we use manual_offset_management without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.manual_offset_management.active?).to eq(false)
      end
    end

    context 'when we use manual_offset_management with active status' do
      it 'expect to use proper active status' do
        topic.manual_offset_management(true)
        expect(topic.manual_offset_management.active?).to eq(true)
      end
    end

    context 'when we use manual_offset_management multiple times with different values' do
      it 'expect to use proper active status' do
        topic.manual_offset_management(true)
        topic.manual_offset_management(false)
        expect(topic.manual_offset_management.active?).to eq(true)
      end
    end
  end

  describe '#manual_offset_management?' do
    context 'when active' do
      before { topic.manual_offset_management(true) }

      it { expect(topic.manual_offset_management?).to eq(true) }
    end

    context 'when not active' do
      before { topic.manual_offset_management(false) }

      it { expect(topic.manual_offset_management?).to eq(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:manual_offset_management]).to eq(topic.manual_offset_management.to_h) }
  end
end
