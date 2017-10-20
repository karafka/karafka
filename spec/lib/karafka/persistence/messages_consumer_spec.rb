# frozen_string_literal: true

RSpec.describe Karafka::Persistence::MessagesConsumer do
  subject(:persistence) { described_class }

  let(:messages_consumer1) { instance_double(Karafka::Connection::MessagesConsumer) }
  let(:messages_consumer2) { instance_double(Karafka::Connection::MessagesConsumer) }

  describe '#write' do
    let(:retrieved_result) { persistence.read }

    context 'when messages consumer is present' do

      before { persistence.write(messages_consumer1) }

      it 'expect to overwrite it' do
        persistence.write(messages_consumer2)
        expect(retrieved_result).to eq messages_consumer2
      end
    end

    context 'when messages consumer is missing' do
      before { persistence.write(nil) }

      it 'expect to assign it' do
        persistence.write(messages_consumer1)
        expect(retrieved_result).to eq messages_consumer1
      end
    end
  end

  describe '#read' do
    context 'when messages consumer is present' do
      before { persistence.write(messages_consumer1) }

      it 'expect to retrieve it' do
        expect(persistence.read).to eq messages_consumer1
      end
    end

    context 'when messages consumer is missing' do
      before { persistence.write(nil) }

      it 'expect to raise error' do
        expect { persistence.read }.to raise_error Karafka::Errors::MissingMessagesConsumer
      end
    end
  end
end
