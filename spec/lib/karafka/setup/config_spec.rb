require 'spec_helper'

RSpec.describe Karafka::Setup::Config do
  specify { expect(described_class::Node).to be < OpenStruct }

  describe 'class methods' do
    subject { described_class.new }

    described_class::ROOT_SETTINGS.each do |attribute|
      describe "#{attribute}=" do
        let(:value) { rand }
        before { subject.public_send(:"#{attribute}=", value) }

        it 'assigns a given value' do
          expect(subject.public_send(attribute)).to eq value
        end
      end

      describe "##{attribute}" do
        before do
          subject.public_send(:"#{attribute}=", value)
        end

        context 'when value is assigned' do
          let(:value) { rand }

          it { expect(subject.public_send(attribute)).to eq value }
        end

        context 'when value is not assigned' do
          let(:value) { nil }
          let(:default_value) { rand }

          context 'and there is a default' do
            before do
              expect(Karafka::Setup::Defaults)
                .to receive(:respond_to?)
                .and_return(true)
                .at_least(:once)

              expect(Karafka::Setup::Defaults)
                .to receive(attribute)
                .and_return(default_value)
            end

            it { expect(subject.public_send(attribute)).to eq default_value }
          end

          context 'but there is no default' do
            before do
              expect(Karafka::Setup::Defaults)
                .to receive(:respond_to?)
                .and_return(false)
                .at_least(:once)
            end

            it { expect(subject.public_send(attribute)).to eq nil }
          end
        end
      end
    end

    describe '.setup' do
      subject { described_class }
      let(:instance) { described_class.new }
      let(:config_instance) { described_class.instance_variable_get('@config') }

      before do
        instance
        config_instance

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
        described_class.instance_variable_set('@config', config_instance)
      end

      it { expect { |block| subject.setup(&block) }.to yield_with_args }
    end
  end

  describe 'instance methods' do
    subject { described_class.new }

    describe '#setup_components' do
      it 'expect to take descendants of BaseConfigurator and run setuo on each' do
        Karafka::Setup::Configurators::Base.descendants.each do |descendant_class|
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

    describe 'example node' do
      let(:hosts) { rand }
      let(:kafka_node) { { hosts: hosts } }

      before { subject.kafka = kafka_node }

      it 'expect to return a node' do
        expect(subject.kafka.hosts).to eq hosts
      end

      it 'expect to be a Node object' do
        expect(subject.kafka).to be_a described_class::Node
      end
    end
  end
end
