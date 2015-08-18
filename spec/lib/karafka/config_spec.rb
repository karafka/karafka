require 'spec_helper'

RSpec.describe Karafka::Config do
  subject { described_class.new }

  described_class::SETTINGS.each do |attribute|
    describe "#{attribute}=" do
      let(:value) { rand }
      before { subject.public_send(:"#{attribute}=", value) }

      it 'assigns a given value' do
        expect(subject.public_send(attribute)).to eq value
      end
    end
  end

  describe '#receive_events?' do
    context 'when we dont want to receive events' do
      before { subject.receive_events = false }

      it { expect(subject.receive_events?).to eq false }
    end

    context 'whe we want to send events' do
      before { subject.receive_events = true }

      it { expect(subject.receive_events?).to eq true }
    end
  end

  describe '.setup' do
    subject { described_class }
    let(:instance) { described_class.new }
    let(:block) { -> {} }

    before do
      instance

      expect(subject)
        .to receive(:new)
        .and_return(instance)

      expect(block)
        .to receive(:call)
        .with(instance)

      expect(instance)
        .to receive(:freeze)
    end

    it { subject.setup(&block) }
  end
end
