# frozen_string_literal: true

RSpec.describe_current do
  subject(:callback) { described_class.new(subscription_group, client_id) }

  let(:subscription_group) { build(:routing_subscription_group) }
  let(:subscription_group_id) { subscription_group.id }
  let(:consumer_group_id) { consumer_group.id }
  let(:client_id) { rand.to_s }
  let(:consumer_group) { subscription_group.consumer_group }
  let(:tpl) { rand }
  let(:monitor) { Karafka::Instrumentation::Monitor.new }
  let(:previous_monitor) { Karafka::App.config.monitor }

  before do
    previous_monitor
    allow(monitor).to receive(:instrument)
    Karafka::App.config.monitor = monitor
  end

  after { Karafka::App.config.monitor = previous_monitor }

  describe '#on_partitions_revoke' do
    before { callback.on_partitions_revoke(tpl) }

    it 'expect to publish appropriate event' do
      expect(monitor).to have_received(:instrument).with(
        'rebalance.partitions_revoke',
        caller: callback,
        subscription_group_id: subscription_group_id,
        subscription_group: subscription_group,
        consumer_group_id: consumer_group_id,
        consumer_group: consumer_group,
        tpl: tpl,
        client_id: client_id
      )
    end

    context 'when handler contains error' do
      let(:tracked_errors) { [] }

      before do
        allow(monitor).to receive(:instrument).and_call_original

        monitor.subscribe('rebalance.partitions_revoke') do
          raise
        end

        local_errors = tracked_errors

        monitor.subscribe('error.occurred') do |event|
          local_errors << event
        end
      end

      it 'expect to contain in, notify and continue as we do not want to crash rdkafka' do
        expect { callback.on_partitions_revoke(tpl) }.not_to raise_error
        expect(tracked_errors.size).to eq(1)
        expect(tracked_errors.first[:type]).to eq('callbacks.rebalance.partitions_revoke.error')
      end
    end
  end

  describe '#on_partitions_assign' do
    before { callback.on_partitions_assign(tpl) }

    it 'expect to publish appropriate event' do
      expect(monitor).to have_received(:instrument).with(
        'rebalance.partitions_assign',
        caller: callback,
        subscription_group_id: subscription_group_id,
        subscription_group: subscription_group,
        consumer_group_id: consumer_group_id,
        consumer_group: consumer_group,
        tpl: tpl,
        client_id: client_id
      )
    end
  end

  describe '#on_partitions_revoked' do
    before { callback.on_partitions_revoked(tpl) }

    it 'expect to publish appropriate event' do
      expect(monitor).to have_received(:instrument).with(
        'rebalance.partitions_revoked',
        caller: callback,
        subscription_group_id: subscription_group_id,
        subscription_group: subscription_group,
        consumer_group_id: consumer_group_id,
        consumer_group: consumer_group,
        tpl: tpl,
        client_id: client_id
      )
    end
  end

  describe '#on_partitions_assigned' do
    before { callback.on_partitions_assigned(tpl) }

    it 'expect to publish appropriate event' do
      expect(monitor).to have_received(:instrument).with(
        'rebalance.partitions_assigned',
        caller: callback,
        subscription_group_id: subscription_group_id,
        subscription_group: subscription_group,
        consumer_group_id: consumer_group_id,
        consumer_group: consumer_group,
        tpl: tpl,
        client_id: client_id
      )
    end
  end
end
