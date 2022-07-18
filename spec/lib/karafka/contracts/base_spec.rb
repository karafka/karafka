# frozen_string_literal: true

RSpec.describe_current do
  subject(:validator_class) do
    Class.new(described_class) do
      configure do |config|
        config.error_messages = YAML.safe_load(
          File.read(
            File.join(Karafka.gem_root, 'config', 'errors.yml')
          )
        ).fetch('en').fetch('validations').fetch('test')
      end

      required(:id) { |id| id.is_a?(String) }
    end
  end

  describe '#validate!' do
    subject(:validation) { validator_class.new.validate!(data) }

    context 'when data is valid' do
      let(:data) { { id: '1' } }

      it { expect { validation }.not_to raise_error }
    end

    context 'when data is not valid' do
      let(:data) { { id: 1 } }

      it { expect { validation }.to raise_error(Karafka::Errors::InvalidConfigurationError) }
    end
  end
end
