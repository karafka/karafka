# frozen_string_literal: true

RSpec.describe Karafka::Responders::Topic do
  subject(:topic) { described_class.new(name, options) }

  let(:name) { 'topic_123.abc-xyz' }
  let(:options) { {} }

  describe '#required?' do
    context 'when topic is optional' do
      let(:options) { { required: false } }

      it { expect(topic.required?).to eq false }
    end

    context 'when topic has no options (default)' do
      it { expect(topic.required?).to eq true }
    end

    context 'when topic is required' do
      let(:options) { { required: true } }

      it { expect(topic.required?).to eq true }
    end
  end

  describe '#async?' do
    context 'when async is off' do
      let(:options) { { async: false } }

      it { expect(topic.async?).to eq false }
    end

    context 'when async has no options (default)' do
      it { expect(topic.async?).to eq false }
    end

    context 'when async is on' do
      let(:options) { { async: true } }

      it { expect(topic.async?).to eq true }
    end
  end

  describe '#to_h' do
    let(:hashed_topic) { topic.to_h }

    it { expect(hashed_topic[:name]).to eq name }
    it { expect(hashed_topic[:required]).to eq topic.required? }
  end
end
