# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:base_command) { described_class.new(options) }

  let(:options) { {} }

  describe '#initialize' do
    context 'when options are provided' do
      let(:options) { { groups: ['group1'], force: true } }

      it 'creates an instance with the provided options' do
        expect(base_command).to be_an_instance_of(described_class)
      end
    end

    context 'when no options are provided' do
      let(:options) { {} }

      it 'creates an instance with empty options' do
        expect(base_command).to be_an_instance_of(described_class)
      end
    end
  end
end
