# frozen_string_literal: true

RSpec.describe Karafka::Persistence::Consumer do
  subject(:persistence) { described_class }

  describe '#fetch' do
    let(:partition) { 1 }
    let(:topic_id) { rand.to_s }
    let(:topic) do
      instance_double(
        Karafka::Routing::Topic,
        persistent: persistent,
        id: topic_id,
        consumer: Karafka::BaseConsumer
      )
    end

    context 'when persistence is disabled' do
      let(:persistent) { false }

      it 'expect not to cache it' do
        r1 = persistence.fetch(topic, partition)
        expect(r1).not_to eq persistence.fetch(topic, partition)
      end
    end

    context 'when persistence is enabled' do
      let(:persistent) { true }

      it 'expect to cache it' do
        r1 = persistence.fetch(topic, partition)
        expect(r1).to eq persistence.fetch(topic, partition)
      end
    end
  end
end
