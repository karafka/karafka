# frozen_string_literal: true

RSpec.describe Karafka::Persistence::Consumer do
  subject(:persistence) { described_class }

  describe '#fetch' do
    let(:partition) { 1 }
    let(:topic_id) { rand.to_s }
    let(:topic) do
      Karafka::Routing::Topic.new(
        rand,
        Karafka::Routing::ConsumerGroup.new(rand),
      ).tap do |topic|
        topic.consumer = Class.new(Karafka::BaseConsumer)
      end
    end

    it 'expect to cache it' do
      r1 = persistence.fetch(topic, partition)
      expect(r1).to eq persistence.fetch(topic, partition)
    end
  end
end
