RSpec.describe Karafka::Responders::Topic do
  subject(:topic) { described_class.new(name, options) }
  let(:name) { 'topic_123.abc-xyz' }
  let(:options) { {} }

  describe '.new' do
    context 'when name is invalid' do
      %w(
        & /31 ół !@
      ).each do |topic_name|
        let(:name) { topic_name }

        it { expect { topic }.to raise_error(Karafka::Errors::InvalidTopicName) }
      end
    end

    context 'when name is valid' do
      it { expect { topic }.not_to raise_error }
    end
  end

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

  describe '#required?' do
    context 'when topic is for multiple usage' do
      let(:options) { { multiple_usage: true } }

      it { expect(topic.multiple_usage?).to eq true }
    end

    context 'when topic has no options (default)' do
      it { expect(topic.multiple_usage?).to eq false }
    end

    context 'when topic is not for multiple usage' do
      let(:options) { { multiple_usage: false } }

      it { expect(topic.multiple_usage?).to eq false }
    end
  end
end
