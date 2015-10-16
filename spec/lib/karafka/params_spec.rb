require 'spec_helper'

RSpec.describe Karafka::Params do
  describe '#build' do
    let(:message) { double(content: content) }
    let(:random_hash) { { rand.to_s => rand.to_s } }

    subject { described_class.build(message, JSON) }

    context 'when we try to build from a hash' do
      let(:content) { random_hash }

      it 'should just create params based on it' do
        expect(subject).to eq content
      end
    end

    context 'when we try to build from string' do
      context 'and it is a vald json string' do
        let(:content) { random_hash.to_json }

        it 'should parse it and put it to params' do
          expect(subject).to eq random_hash
        end
      end

      context 'and it is not a valid json string' do
        let(:random_string) { rand.to_s }
        let(:content) { random_string }

        it 'should create params with message containing that string' do
          expect(subject).to eq('message' => random_string)
        end
      end
    end
  end
end
