# frozen_string_literal: true

RSpec.describe Karafka::Persistence::Consumer do
  subject(:persistence) { described_class }

  let(:consumer1) { instance_double(Karafka::Connection::Consumer) }
  let(:consumer2) { instance_double(Karafka::Connection::Consumer) }

  describe '#write' do
    let(:retrieved_result) { persistence.read }

    context 'when messages consumer is present' do
      before { persistence.write(consumer1) }

      it 'expect to overwrite it' do
        persistence.write(consumer2)
        expect(retrieved_result).to eq consumer2
      end
    end

    context 'when messages consumer is missing' do
      before { persistence.write(nil) }

      it 'expect to assign it' do
        persistence.write(consumer1)
        expect(retrieved_result).to eq consumer1
      end
    end
  end

  describe '#read' do
    context 'when messages consumer is present' do
      before { persistence.write(consumer1) }

      it 'expect to retrieve it' do
        expect(persistence.read).to eq consumer1
      end
    end

    context 'when messages consumer is missing' do
      before { persistence.write(nil) }

      it 'expect to raise error' do
        expect { persistence.read }.to raise_error Karafka::Errors::MissingConsumer
      end
    end
  end
end
