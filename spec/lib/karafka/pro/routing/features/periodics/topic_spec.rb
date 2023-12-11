# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe '#periodics' do
    context 'when we use periodics without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.periodics.active?).to eq(false)
      end
    end

    context 'when we use periodics with active status' do
      it 'expect to use proper active status' do
        topic.periodic(true)
        expect(topic.periodics.active?).to eq(true)
      end
    end

    context 'when we use periodics multiple times with different values' do
      it 'expect to use proper active status' do
        topic.periodic(true)
        topic.periodic(false)
        expect(topic.periodics.active?).to eq(true)
      end
    end
  end

  describe '#periodics?' do
    context 'when active' do
      before { topic.periodic(true) }

      it { expect(topic.periodics?).to eq(true) }
    end

    context 'when not active' do
      before { topic.periodic(false) }

      it { expect(topic.periodics?).to eq(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:periodics]).to eq(topic.periodics.to_h) }
  end
end
