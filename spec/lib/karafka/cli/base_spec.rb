# frozen_string_literal: true

RSpec.describe_current do
  describe 'class methods' do
    subject(:base_cli_class) { described_class }

    describe '#name' do
      it { expect(base_cli_class.send(:name)).to eq 'base' }
    end
  end
end
