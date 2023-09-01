# frozen_string_literal: true

RSpec.describe_current do
  subject(:messages) { Karafka::Messages::Messages.new(batch, {}) }

  let(:message1) { build(:messages_message) }
  let(:message2) { build(:messages_message) }
  let(:batch) { [message1, message2] }

  describe '#each' do
    context 'when not with clean' do
      before { messages.each {} }

      it 'expect not to have all messages cleaned' do
        expect(message1.cleaned?).to eq(false)
        expect(message2.cleaned?).to eq(false)
      end
    end

    context 'when with clean' do
      before { messages.each(clean: true) {} }

      it 'expect to have all messages cleaned' do
        expect(message1.cleaned?).to eq(true)
        expect(message2.cleaned?).to eq(true)
      end
    end
  end
end
