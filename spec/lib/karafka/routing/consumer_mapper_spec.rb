# frozen_string_literal: true

RSpec.describe_current do
  subject(:instance) { described_class.new }

  describe '#call' do
    it 'generates name namespaced with client_id' do
      old_client_id = Karafka::App.config.client_id
      Karafka::App.config.client_id = 'example_client'

      actual_value = instance.call('consumers')
      expect(actual_value).to eq('example_client_consumers')

      Karafka::App.config.client_id = old_client_id
    end
  end
end
