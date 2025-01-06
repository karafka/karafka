# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe '#dead_letter_queue' do
    context 'when we use dead_letter_queue without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.dead_letter_queue.active?).to be(false)
        expect(topic.dead_letter_queue.strategy).to be_a(Proc)
      end
    end

    context 'when we use dead_letter_queue with topic name' do
      it 'expect to use proper active status' do
        topic.dead_letter_queue(topic: 'test')
        expect(topic.dead_letter_queue.active?).to be(true)
      end
    end

    context 'when we use dead_letter_queue multiple times with different values' do
      it 'expect to use proper active status' do
        topic.dead_letter_queue(topic: 'test')
        topic.dead_letter_queue(topic: nil)
        expect(topic.dead_letter_queue.active?).to be(true)
      end
    end

    context 'when we use alternative retry count' do
      it 'expect to use it' do
        max_retries = 10
        topic.dead_letter_queue(max_retries: max_retries)
        expect(topic.dead_letter_queue.max_retries).to eq(max_retries)
      end
    end

    context 'when we assign custom strategy' do
      it 'expect to use it' do
        strategy = -> {}
        topic.dead_letter_queue(strategy: strategy)
        expect(topic.dead_letter_queue.strategy).to eq(strategy)
      end
    end
  end

  describe '#dead_letter_queue?' do
    context 'when not active' do
      before { topic.dead_letter_queue }

      it { expect(topic.dead_letter_queue?).to be(false) }
    end

    context 'when active' do
      before { topic.dead_letter_queue(topic: 'test') }

      it { expect(topic.dead_letter_queue?).to be(true) }
    end
  end

  describe '#strategy (default)' do
    let(:strategy) { topic.dead_letter_queue.strategy }

    context 'when we are beyond number of attempts' do
      it { expect(strategy.call([], 4)).to eq(:dispatch) }
    end

    context 'when we are below number of attempts' do
      it { expect(strategy.call([], 3)).to eq(:retry) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:dead_letter_queue]).to eq(topic.dead_letter_queue.to_h) }
  end
end
