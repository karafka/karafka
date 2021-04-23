# frozen_string_literal: true

RSpec.describe_current do
  subject(:groups) { described_class.new.call(consumer_group_topics) }

  context 'when there is just one topic in the consumer group' do
    let(:consumer_group_topics) { [build(:routing_topic)] }

    it { expect(groups.size).to eq(1) }
  end

  context 'when there are more topics with the same setings' do
    let(:consumer_group_topics) { Array.new(3) { build(:routing_topic) } }

    it { expect(groups.size).to eq(1) }
  end

  context 'when there are topics but they have different kafka settings' do
    let(:topic1) { build(:routing_topic) }
    let(:topic2) { build(:routing_topic, kafka: { seed_brokers: rand }) }
    let(:consumer_group_topics) { [topic1, topic2] }

    it { expect(groups.size).to eq(2) }
  end

  pending
end
