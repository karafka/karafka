# frozen_string_literal: true

RSpec.describe_current do
  describe '.call' do
    let(:messages) do
      Array.new(3) do
        instance_double(Karafka::Messages::Message).tap do |msg|
          allow(msg).to receive(:payload=)
        end
      end
    end

    context 'when results is nil' do
      it 'does nothing' do
        described_class.call(messages, nil)

        messages.each do |msg|
          expect(msg).not_to have_received(:payload=)
        end
      end
    end

    context 'when results are present' do
      let(:results) { %w[payload1 payload2 payload3] }

      it 'injects payloads into messages' do
        described_class.call(messages, results)

        expect(messages[0]).to have_received(:payload=).with('payload1')
        expect(messages[1]).to have_received(:payload=).with('payload2')
        expect(messages[2]).to have_received(:payload=).with('payload3')
      end
    end

    context 'when results contain deserialization errors' do
      let(:error_marker) { Karafka::Deserializing::Parallel::DESERIALIZATION_ERROR }
      let(:results) { [error_marker, 'payload2', 'payload3'] }

      it 'skips messages with errors, leaving them for lazy deserialization retry' do
        described_class.call(messages, results)

        expect(messages[0]).not_to have_received(:payload=)
      end

      it 'still injects successful results' do
        described_class.call(messages, results)

        expect(messages[1]).to have_received(:payload=).with('payload2')
        expect(messages[2]).to have_received(:payload=).with('payload3')
      end
    end

    context 'when multiple errors are present' do
      let(:error_marker) { Karafka::Deserializing::Parallel::DESERIALIZATION_ERROR }
      let(:results) { [error_marker, error_marker, 'payload3'] }

      it 'skips all error messages' do
        described_class.call(messages, results)

        expect(messages[0]).not_to have_received(:payload=)
        expect(messages[1]).not_to have_received(:payload=)
        expect(messages[2]).to have_received(:payload=).with('payload3')
      end
    end
  end
end
