# frozen_string_literal: true

RSpec.describe_current do
  subject(:config_class) { described_class }

  describe '#setup' do
    it { expect { |block| config_class.setup(&block) }.to yield_with_args }
  end

  describe '#validate!' do
    let(:invalid_configure) do
      lambda do
        Karafka::App.setup do |config|
          config.client_id = nil
        end
      end
    end

    let(:valid_configure) do
      lambda do
        Karafka::App.setup do |config|
          config.client_id = rand(100).to_s
        end
      end
    end

    after { valid_configure.call }

    context 'when configuration has errors' do
      let(:error_class) { ::Karafka::Errors::InvalidConfigurationError }
      let(:error_message) { { client_id: ['must be filled'] }.to_s }

      it 'raise InvalidConfigurationError exception' do
        expect { invalid_configure.call }.to raise_error do |error|
          expect(error).to be_a(error_class)
          expect(error.message).to eq(error_message)
        end
      end
    end

    context 'when configuration is valid' do
      it 'not raise InvalidConfigurationError exception' do
        expect { valid_configure.call }.not_to raise_error
      end
    end
  end
end
