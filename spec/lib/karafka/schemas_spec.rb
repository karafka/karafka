# frozen_string_literal: true

RSpec.describe Karafka::Schemas do
  describe '#TOPIC_REGEXP' do
    subject(:match) { input.match? described_class::TOPIC_REGEXP }

    context 'when topic name is valid' do
      let(:input) { 'name' }

      it { is_expected.to eq true }
    end

    context 'when topic name is invalid' do
      let(:input) { '$%^&*' }

      it { is_expected.to eq false }
    end
  end
end
