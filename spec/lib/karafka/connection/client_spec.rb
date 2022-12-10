# frozen_string_literal: true

RSpec.describe_current do
  subject(:client) { described_class.new(subscription_group) }

  let(:subscription_group) { build(:routing_subscription_group) }

  describe '#name' do
    let(:client_id) { SecureRandom.hex(6) }
    let(:start_nr) { client.name.split('-').last.to_i }

    before { Karafka::App.config.client_id = client_id }

    after { client.stop }

    # Kafka counts all the consumers one after another, that is why we need to check it in one
    # spec
    it 'expect to give it proper names within the lifecycle' do
      expect(client.name).to eq("#{Karafka::App.config.client_id}#consumer-#{start_nr}")
      client.reset
      expect(client.name).to eq("#{Karafka::App.config.client_id}#consumer-#{start_nr + 1}")
      client.stop
      expect(client.name).to eq("#{Karafka::App.config.client_id}#consumer-#{start_nr + 1}")
    end
  end
end
