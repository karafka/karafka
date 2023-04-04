# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe '#throttling' do
    context 'when we use throttling without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.throttling.active?).to eq(false)
      end
    end

    context 'when we use throttling with good limit value' do
      it 'expect to use proper active status' do
        topic.throttling(limit: 100)
        expect(topic.throttling.active?).to eq(true)
      end
    end

    context 'when we use throttling multiple times with different values' do
      it 'expect to use proper active status' do
        topic.throttling(limit: 100)
        topic.throttling(limit: Float::INFINITY)
        expect(topic.throttling.active?).to eq(true)
      end
    end
  end

  describe '#throttling?' do
    context 'when active' do
      before { topic.throttling(limit: 100) }

      it { expect(topic.throttling?).to eq(true) }
    end

    context 'when not active' do
      before { topic.throttling }

      it { expect(topic.throttling?).to eq(false) }
    end

    context 'when active via custom throttler class' do
      before { topic.throttling(throttler_class: Class.new) }

      it { expect(topic.throttling?).to eq(true) }
    end
  end

  describe '#throttler' do
    context 'when we use the default throttler' do
      it 'expect no build it with limit and interval' do
        expect(topic.throttling.throttler).to be_a(Karafka::Pro::Processing::Throttler)
      end
    end

    context 'when we use a custom class' do
      before { topic.throttling(throttler_class: throttler_class) }

      let(:throttler_class) { Class.new }

      it 'expect not to use the limit and interval' do
        expect(topic.throttling.throttler).to be_a(throttler_class)
      end
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:throttling]).to eq(topic.throttling.to_h) }
  end
end
