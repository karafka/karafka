# frozen_string_literal: true

RSpec.describe Karafka::Setup::Config do
  subject(:config_class) { described_class }

  describe '#setup' do
    it { expect { |block| config_class.setup(&block) }.to yield_with_args }
  end

  describe '#setup_components' do
    before do
      Karafka::Setup::Configurators::Base.descendants.each do |descendant_class|
        config = double

        expect(descendant_class)
          .to receive(:new)
          .with(config_class.config)
          .and_return(config)
          .at_least(:once)

        expect(config)
          .to receive(:setup)
          .at_least(:once)
      end
    end

    it 'expect to take descendants of BaseConfigurator and run setup on each' do
      config_class.send :setup_components
    end
  end

  describe '#validate!' do
    context 'when configuration has errors' do
      let(:error_class) { ::Karafka::Errors::InvalidConfiguration }
      let(:error_message) { { client_id: ['must be filled'] }.to_s }

      before do
        module Karafka
          class App
            setup do |config|
              config.client_id = nil
            end
          end
        end
      end

      it 'raise InvalidConfiguration exception' do
        expect { config_class.send(:validate!) }.to raise_error do |error|
          expect(error).to be_a(error_class)
          expect(error.message).to eq(error_message)
        end
      end

      after do
        module Karafka
          class App
            setup do |config|
              config.client_id = rand(100).to_s
            end
          end
        end
      end
    end

    context 'when configuration is valid' do
      it 'not raise InvalidConfiguration exception' do
        expect { config_class.send(:validate!) }
          .not_to raise_error
      end
    end
  end
end
