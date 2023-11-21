# frozen_string_literal: true

RSpec.describe_current do
  subject(:tracker) { described_class.instance }

  let(:subscription_group1) { build(:routing_subscription_group) }
  let(:topic1) { subscription_group1.topics.first }
  let(:subscription_group2) { build(:routing_subscription_group) }
  let(:topic2) { subscription_group2.topics.first }

  after { tracker.clear }

  it { expect(tracker.current).to eq({}) }

  let(:assign_event) do
    tpl = Rdkafka::Consumer::TopicPartitionList.new
    tpl.add_topic(topic1.name, [0, 1, 2])

    {
      subscription_group: subscription_group1,
      tpl: tpl
    }
  end

  describe 'events naming' do
    it 'expect to match correct methods' do
      expect(NotificationsChecker.valid?(tracker)).to eq(true)
    end
  end

  context 'when we receive an assignment' do
    before { tracker.on_rebalance_partitions_assigned(assign_event) }

    it { expect(tracker.current).to be_frozen }
    it { expect(tracker.current[topic1]).to eq([0, 1, 2]) }

    context 'when we clear' do
      before { tracker.clear }

      it { expect(tracker.current).to eq({}) }
    end

    context 'when we reset given subscription group' do
      before do
        assign_event2 = assign_event.dup
        assign_event2[:subscription_group] = subscription_group2
        tracker.on_rebalance_partitions_assigned(assign_event2)
        tracker.on_client_reset(assign_event2)
      end

      it { expect(tracker.current.key?(topic1)).to eq(true) }
      it { expect(tracker.current.key?(topic2)).to eq(false) }
    end
  end

  context 'when we got and lost assignment' do
    before do
      tracker.on_rebalance_partitions_assigned(assign_event)
      tracker.on_rebalance_partitions_revoked(assign_event)
    end

    it { expect(tracker.current).to eq({}) }
  end

  context 'when we got assignment and lost part of it' do
    before do
      tracker.on_rebalance_partitions_assigned(assign_event)
      assign_event[:tpl].to_h.values.first.pop
      tracker.on_rebalance_partitions_revoked(assign_event)
    end

    it { expect(tracker.current.values.first).to eq([2]) }
  end
end
