# frozen_string_literal: true

RSpec.describe_current do
  subject(:client) { described_class.new(subscription_group) }

  let(:subscription_group) { build(:routing_subscription_group) }

  describe '#name' do
    let(:client_id) { SecureRandom.hex(6) }
    let(:start_nr) { client.name.split('-').last.to_i }

    before do
      Karafka::App.config.client_id = client_id
      client.send(:kafka)
    end

    after { client.stop }

    # Kafka counts all the consumers one after another, that is why we need to check it in one
    # spec
    it 'expect to give it proper names within the lifecycle' do
      expect(client.name).to eq("#{Karafka::App.config.client_id}#consumer-#{start_nr}")
      client.reset
      client.send(:kafka)
      expect(client.name).to eq("#{Karafka::App.config.client_id}#consumer-#{start_nr + 1}")
      client.stop
      client.send(:kafka)
      expect(client.name).to eq("#{Karafka::App.config.client_id}#consumer-#{start_nr + 2}")
    end
  end

  describe '#assignment' do
    let(:kafka) { instance_double(Rdkafka::Consumer) }

    before do
      allow(client).to receive(:kafka).and_return(kafka)
      allow(kafka).to receive(:assignment)
    end

    it 'expect to delegate to client' do
      client.assignment

      expect(kafka).to have_received(:assignment)
    end
  end

  describe '#assignment_lost?' do
    let(:kafka) { instance_double(Rdkafka::Consumer) }

    before do
      allow(client).to receive(:kafka).and_return(kafka)
      allow(kafka).to receive(:assignment_lost?)
    end

    it 'expect to delegate to client' do
      client.assignment_lost?

      expect(kafka).to have_received(:assignment_lost?)
    end
  end
end
