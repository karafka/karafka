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
      expect(NotificationsChecker.valid?(tracker)).to be(true)
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

      it { expect(tracker.current.key?(topic1)).to be(true) }
      it { expect(tracker.current.key?(topic2)).to be(false) }
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

  describe '#on_client_events_poll' do
    let(:client) { instance_double(Karafka::Connection::Client, assignment_lost?: false) }
    let(:events_poll_event) do
      {
        caller: client,
        subscription_group: subscription_group1
      }
    end

    context 'when assignment was not lost' do
      before do
        tracker.on_rebalance_partitions_assigned(assign_event)
        tracker.on_client_events_poll(events_poll_event)
      end

      it 'expect not to clear any assignments' do
        expect(tracker.current[topic1]).to eq([0, 1, 2])
      end
    end

    context 'when assignment was lost' do
      before do
        allow(client).to receive(:assignment_lost?).and_return(true)
        tracker.on_rebalance_partitions_assigned(assign_event)
      end

      context 'with single subscription group' do
        before { tracker.on_client_events_poll(events_poll_event) }

        it 'expect to clear assignments for the subscription group' do
          expect(tracker.current).to eq({})
        end
      end

      context 'with multiple subscription groups' do
        let(:client2) { instance_double(Karafka::Connection::Client, assignment_lost?: false) }
        let(:events_poll_event2) do
          {
            caller: client2,
            subscription_group: subscription_group2
          }
        end

        before do
          # Assign to both subscription groups
          assign_event2 = assign_event.dup
          assign_event2[:subscription_group] = subscription_group2
          tracker.on_rebalance_partitions_assigned(assign_event2)

          # Only subscription_group1 loses assignment
          tracker.on_client_events_poll(events_poll_event)
        end

        it 'expect to only clear assignments for the affected subscription group' do
          expect(tracker.current.key?(topic1)).to be(false)
          expect(tracker.current.key?(topic2)).to be(true)
          expect(tracker.current[topic2]).to eq([0, 1, 2])
        end
      end
    end

    context 'when called multiple times with no assignment loss' do
      before do
        tracker.on_rebalance_partitions_assigned(assign_event)
      end

      it 'expect to be safe to call repeatedly without side effects' do
        10.times { tracker.on_client_events_poll(events_poll_event) }
        expect(tracker.current[topic1]).to eq([0, 1, 2])
      end
    end
  end

  describe '#inspect' do
    let(:subscription_group) { build(:routing_subscription_group) }
    let(:topic) { subscription_group.topics.first }

    let(:assign_event) do
      tpl = Rdkafka::Consumer::TopicPartitionList.new
      tpl.add_topic(topic.name, [0, 1, 2])
      { subscription_group: subscription_group, tpl: tpl }
    end

    context 'when tracker has no assignments' do
      it 'expect to show empty assignments' do
        expect(tracker.inspect).to include('assignments={}')
      end
    end

    context 'when tracker has assignments' do
      before { tracker.on_rebalance_partitions_assigned(assign_event) }

      it 'expect to show current assignments with topic names' do
        result = tracker.inspect

        expect(result).to include('assignments=')
        expect(result).to include(topic.name)
        expect(result).to include('[0, 1, 2]')
      end
    end

    context 'when mutex is locked' do
      it 'expect to show busy status without blocking' do
        tracker.instance_variable_get(:@mutex).lock

        begin
          expect(tracker.inspect).to include('busy')
        ensure
          tracker.instance_variable_get(:@mutex).unlock
        end
      end
    end

    context 'with concurrent access' do
      it 'expect to handle concurrent inspect and assignment changes safely' do
        errors = []
        inspecting = true

        modifier = Thread.new do
          while inspecting
            tracker.on_rebalance_partitions_assigned(assign_event)
            tracker.clear
          end
        rescue StandardError => e
          errors << e
        end

        inspector = Thread.new do
          1_000_000.times { tracker.inspect }
          inspecting = false
        rescue StandardError => e
          errors << e
        end

        [modifier, inspector].each(&:join)

        expect(errors).to be_empty
      end
    end
  end
end
