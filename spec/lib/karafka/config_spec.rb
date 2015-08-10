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

  describe '#send_events?' do
    context 'when we dont want to send events' do
      before { subject.send_events = false }

      it { expect(subject.send_events?).to eq false }
    end

    context 'whe we want to send events' do
      before { subject.send_events = true }

      it { expect(subject.send_events?).to eq true }
    end
  end

  describe '.configure' do
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

    it { subject.configure(&block) }
  end
end
