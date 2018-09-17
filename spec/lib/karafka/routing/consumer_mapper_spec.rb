# frozen_string_literal: true

RSpec.describe Karafka::Routing::ConsumerMapper do
  subject(:instance) { described_class.new }

  describe '#call' do
    it 'generates name namespaced to underscored client_id' do
      old_client_id = Karafka::App.config.client_id
      Karafka::App.config.client_id = 'ExampleClient'

      actual_value = instance.call('consumers')
      expect(actual_value).to eq('example_client_consumers')

      Karafka::App.config.client_id = old_client_id
    end
  end
end
