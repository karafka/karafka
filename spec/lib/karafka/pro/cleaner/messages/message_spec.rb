# frozen_string_literal: true

RSpec.describe_current do
  subject(:message) { build(:messages_message) }

  describe '#payload' do
    context 'when message was not cleaned' do
      it { expect { message.payload }.not_to raise_error }
    end

    context 'when message was cleaned' do
      let(:expected_error) { Karafka::Pro::Cleaner::Errors::MessageCleanedError }

      before { message.clean! }

      it { expect { message.payload }.to raise_error(expected_error) }
    end
  end

  describe '#cleaned? and #clean!' do
    context 'when message was not cleaned' do
      it { expect(message.cleaned?).to eq(false) }
      it { expect(message.raw_payload).not_to eq(false) }
      it { expect(message.deserialized?).to eq(false) }
    end

    context 'when message was cleaned' do
      before { message.clean! }

      it { expect(message.cleaned?).to eq(true) }
      it { expect(message.deserialized?).to eq(false) }
      it { expect(message.raw_payload).to eq(false) }
    end

    context 'when message was deserialized and cleaned' do
      before do
        message.payload
        message.clean!
      end

      it { expect(message.cleaned?).to eq(true) }
      it { expect(message.deserialized?).to eq(false) }
      it { expect(message.raw_payload).to eq(false) }
    end
  end
end
