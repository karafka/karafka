# frozen_string_literal: true

RSpec.describe_current do
  subject(:consumer) do
    consumer = described_class.new
    consumer.client = client
    consumer
  end

  let(:client) { instance_double(Karafka::Connection::Client, pause: true) }
  let(:messages) { [message1, message2] }
  let(:message1) { build(:messages_message, raw_payload: payload1.to_json) }
  let(:message2) { build(:messages_message, raw_payload: payload2.to_json) }
  let(:payload1) { { '1' => '2' } }
  let(:payload2) { { '3' => '4' } }

  context 'when messages are available to the consumer' do
    before do
      consumer.messages = messages

      allow(client).to receive(:mark_as_consumed).with(messages.first)
      allow(client).to receive(:mark_as_consumed).with(messages.last)

      allow(ActiveJob::Base).to receive(:execute).with(payload1)
      allow(ActiveJob::Base).to receive(:execute).with(payload2)
    end

    it 'expect to decode them and run active job executor' do
      consumer.consume

      expect(ActiveJob::Base).to have_received(:execute).with(payload1)
      expect(ActiveJob::Base).to have_received(:execute).with(payload2)
    end

    it 'expect to mark as consumed on each message' do
      consumer.consume

      expect(client).to have_received(:mark_as_consumed).with(messages.first)
      expect(client).to have_received(:mark_as_consumed).with(messages.last)
    end
  end
end
