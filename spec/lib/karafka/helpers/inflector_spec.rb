# frozen_string_literal: true

RSpec.describe Karafka::Helpers::Inflector do
  describe '#map' do
    subject(:map) { described_class.map(string) }

    context 'when we have string with a non namespaced controller name' do
      let(:string) { 'SomeFancyController' }

      it { is_expected.to eq 'some_fancy_controller' }
    end

    context 'when we have string with a namespaced controller' do
      let(:string) { 'Namespaced::FancyController' }

      it { is_expected.to eq 'namespaced_fancy_controller' }
    end
  end
end
