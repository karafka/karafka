# frozen_string_literal: true

RSpec.describe Karafka::Persistence::Consumer do
  subject(:persistence) { described_class }

  describe '#fetch' do
    let(:partition) { 1 }
    let(:topic) { build(:routing_topic) }

    it 'expect to cache it' do
      r1 = persistence.fetch(topic, partition)
      expect(r1).to eq persistence.fetch(topic, partition)
    end
  end
end
