# frozen_string_literal: true

RSpec.describe_current do
  subject(:limiter) { described_class.new(manager, collapser) }

  4.times { |i| let(:"message#{i + 1}") { build(:messages_message) } }

  let(:messages) { [message1, message2, message3, message4] }
  let(:manager) { Karafka::Pro::Processing::VirtualOffsetManager.new('topic', 0) }
  let(:collapser) { Karafka::Pro::Processing::Collapser.new }

  before { manager.register(messages.map(&:offset)) }

  context 'when not collapsed' do
    it 'expect not to filter anything' do
      expect { limiter.apply!(messages) }.not_to(change { messages })
    end
  end

  context 'when collapsed' do
    before do
      collapser.collapse_until!(messages.last.offset)
      collapser.refresh!(messages.first.offset)
    end

    context 'when nothing marked' do
      it { expect { limiter.apply!(messages) }.not_to(change { messages }) }
    end

    context 'when all marked' do
      before { manager.mark_until(messages.last) }

      it 'expect to remove all' do
        limiter.apply!(messages)
        expect(messages).to eq([])
      end
    end

    context 'when some marked' do
      before do
        manager.mark(messages[0])
        manager.mark(messages[1])
      end

      it 'expect to remove non-marked' do
        limiter.apply!(messages)
        expect(messages).to eq([message3, message4])
      end
    end
  end
end
