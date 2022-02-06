# frozen_string_literal: true

RSpec.describe_current do
  subject(:validator_class) do
    Class.new(described_class) do
      params do
        required(:id).filled(:str?)
      end
    end
  end

  describe '#validate!' do
    subject(:validation) { validator_class.new.validate!(data, ArgumentError) }

    context 'when data is valid' do
      let(:data) { { id: '1' } }

      it { expect { validation }.not_to raise_error }
    end

    context 'when data is not valid' do
      let(:data) { { id: 1 } }

      it { expect { validation }.to raise_error(ArgumentError) }
    end
  end
end
