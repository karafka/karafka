# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:subscription_group) { build(:routing_subscription_group) }

  let(:active_topic) do
    instance_spy(
      Karafka::Routing::Topic,
      active?: true,
      direct_assignments: instance_spy(
        Karafka::Pro::Routing::Features::DirectAssignments::Config,
        active?: false
      ),
      subscription_name: 'active_topic'
    )
  end

  let(:inactive_topic) { instance_spy(Karafka::Routing::Topic, active?: false) }

  let(:direct_assignment_active_topic) do
    instance_spy(
      Karafka::Routing::Topic,
      active?: true,
      direct_assignments: instance_spy(
        Karafka::Pro::Routing::Features::DirectAssignments::Config,
        active?: true,
        partitions: [1, 2, 3]
      ),
      subscription_name: 'direct_topic'
    )
  end

  let(:topics) { [active_topic, inactive_topic, direct_assignment_active_topic] }

  before { allow(subscription_group).to receive(:topics).and_return(topics) }

  describe '#subscriptions' do
    context 'when there are active topics without direct assignments' do
      it 'returns an array of subscription names' do
        expect(subscription_group.subscriptions).to eq(['active_topic'])
      end
    end

    context 'when all active topics have direct assignments' do
      let(:topics) { [direct_assignment_active_topic] }

      it 'returns false indicating no subscriptions' do
        expect(subscription_group.subscriptions).to be false
      end
    end
  end

  describe '#assignments' do
    let(:consumer) { instance_spy(Karafka::Connection::Proxy) }
    let(:iterator_expander) { instance_spy(Karafka::Pro::Iterator::Expander) }
    let(:tpl_builder) { instance_spy(Karafka::Pro::Iterator::TplBuilder) }
    let(:topic_partition_list) { instance_spy(Rdkafka::Consumer::TopicPartitionList) }

    before do
      allow(Karafka::Pro::Iterator::Expander).to receive(:new).and_return(iterator_expander)
      allow(iterator_expander).to receive(:call).with(any_args).and_return(topics)
      allow(Karafka::Pro::Iterator::TplBuilder).to receive(:new).and_return(tpl_builder)
      allow(tpl_builder).to receive(:call).and_return(topic_partition_list)
    end

    context 'when there are active topics with direct assignments' do
      it 'returns a topic partition list for assignments' do
        expect(subscription_group.assignments(consumer)).to eq(topic_partition_list)
      end
    end

    context 'when there are no active topics with direct assignments' do
      let(:topics) { [active_topic, inactive_topic] } # No topics with active direct assignments

      it 'returns false indicating no assignments' do
        expect(subscription_group.assignments(consumer)).to be false
      end
    end
  end
end
