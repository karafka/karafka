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

  describe '#kafka_hosts' do
    before { subject.kafka_hosts = kafka_hosts }

    context 'when kafka hosts are not provided' do
      let(:kafka_hosts) { nil }
      let(:broker_manager) { double }
      let(:brokers) { [Karafka::Connection::Broker.new({}.to_json)] }

      it 'expect to use broker manager to discover them' do
        expect(Karafka::Connection::BrokerManager)
          .to receive(:new)
          .and_return(broker_manager)

        expect(broker_manager)
          .to receive(:all)
          .and_return(brokers)

        expect(subject.kafka_hosts).to eq brokers.map(&:host)
      end
    end

    context 'when kafka hosts were provided' do
      let(:kafka_hosts) { double }

      it 'expect not to use broker manager to discover them' do
        expect(Karafka::Connection::BrokerManager)
          .not_to receive(:new)

        expect(subject.kafka_hosts).to eq kafka_hosts
      end
    end
  end

  describe '.setup' do
    subject { described_class }
    let(:instance) { described_class.new }

    before do
      instance

      @config = described_class.instance_variable_get('@config')
      described_class.instance_variable_set('@config', nil)

      expect(subject)
        .to receive(:new)
        .and_return(instance)

      expect(instance)
        .to receive(:setup_components)

      expect(instance)
        .to receive(:freeze)
    end

    after do
      described_class.instance_variable_set('@config', @config)
    end

    it { expect { |block| subject.setup(&block) }.to yield_with_args }
  end
end

RSpec.describe Karafka::Config do
  subject { described_class.new }

  describe '#setup_components' do
    it 'expect to take descendants of BaseConfigurator and run setuo on each' do
      Karafka::Configurators::Base.descendants.each do |descendant_class|
        config = double

        expect(descendant_class)
          .to receive(:new)
          .with(subject)
          .and_return(config)
          .at_least(:once)

        expect(config)
          .to receive(:setup)
          .at_least(:once)
      end

      subject.send :setup_components
    end
  end
end
