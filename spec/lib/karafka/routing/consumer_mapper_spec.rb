# frozen_string_literal: true

RSpec.describe Karafka::Routing::ConsumerMapper do
  describe '#call' do
    it 'generates name namespaced to underscored client_id' do
      old_client_id = Karafka::App.config.client_id
      Karafka::App.config.client_id = 'ExampleClient'

      actual_value = Karafka::Routing::ConsumerMapper.call('consumers')
      expect(actual_value).to eq('example_client_consumers')

      Karafka::App.config.client_id = old_client_id
    end
  end
end
