# frozen_string_literal: true

RSpec.describe Karafka::Persistence::Client do
  subject(:persistence) { described_class }

  let(:client1) { instance_double(Karafka::Connection::Client) }
  let(:client2) { instance_double(Karafka::Connection::Client) }

  describe '#write' do
    let(:retrieved_result) { persistence.read }

    context 'when messages client is present' do
      before { persistence.write(client1) }

      it 'expect to overwrite it' do
        persistence.write(client2)
        expect(retrieved_result).to eq client2
      end
    end

    context 'when messages client is missing' do
      before { persistence.write(nil) }

      it 'expect to assign it' do
        persistence.write(client1)
        expect(retrieved_result).to eq client1
      end
    end
  end

  describe '#read' do
    context 'when messages client is present' do
      before { persistence.write(client1) }

      it 'expect to retrieve it' do
        expect(persistence.read).to eq client1
      end
    end

    context 'when messages client is missing' do
      before { persistence.write(nil) }

      it 'expect to raise error' do
        expect { persistence.read }.to raise_error Karafka::Errors::MissingClientError
      end
    end
  end
end
