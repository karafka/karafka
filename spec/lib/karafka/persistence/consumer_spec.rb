# frozen_string_literal: true

RSpec.describe Karafka::Persistence::Consumer do
  subject(:persistence) { described_class }

  describe '#fetch' do
    let(:partition) { 1 }
    let(:topic_id) { rand.to_s }
    let(:topic) do
      instance_double(
        Karafka::Routing::Topic,
        id: topic_id,
        consumer: Karafka::BaseConsumer
      )
    end

    it 'expect to cache it' do
      r1 = persistence.fetch(topic, partition)
      expect(r1).to eq persistence.fetch(topic, partition)
    end
  end
end
