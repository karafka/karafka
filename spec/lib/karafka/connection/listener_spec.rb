# frozen_string_literal: true

RSpec.describe_current do
  subject(:listener) do
    described_class.new(
      subscription_group,
      jobs_queue,
      scheduler
    )
  end

  let(:subscription_group) { build(:routing_subscription_group, topics: [routing_topic]) }
  let(:jobs_queue) { Karafka::Processing::JobsQueue.new }
  let(:scheduler) { Karafka::Processing::Schedulers::Default.new(jobs_queue) }
  let(:client) { Karafka::Connection::Client.new(subscription_group, -> { true }) }
  let(:routing_topic) { build(:routing_topic) }
  let(:status) { Karafka::Connection::Status.new }

  before do
    allow(status.class).to receive(:new).and_return(status)
    allow(client.class).to receive(:new).and_return(client)
    allow(client).to receive(:assignment).and_return([])
    allow(client).to receive(:batch_poll).and_return([])
    allow(client).to receive(:ping)
    allow(status).to receive(:running?).and_return(true, false)
    allow(status).to receive(:quiet?).and_return(true, false)
  end

  after { client.stop }

  context 'when all goes well' do
    before do
      allow(client).to receive(:commit_offsets)
      listener.call
    end

    it 'expect to run proper instrumentation' do
      Karafka.monitor.subscribe('connection.listener.before_fetch_loop') do |event|
        expect(event.payload[:subscription_group]).to eq(subscription_group)
        expect(event.payload[:client]).to eq(subscription_group)
        expect(event.payload[:caller]).to eq(listener)
      end
    end
  end

  context 'when we have lost partitions during rebalance and actions need to be taken' do
    let(:revoked_partitions) { { routing_topic.name => [2] } }

    before do
      allow(client)
        .to receive(:commit_offsets)

      allow(client.rebalance_manager)
        .to receive(:revoked_partitions)
        .and_return(revoked_partitions)

      listener.call

      # Giving enough time to consume the job
      sleep(0.5)
    end

    it 'expect the revoke job to be consumed meanwhile' do
      expect(jobs_queue.statistics).to eq(busy: 0, enqueued: 0)
    end
  end

  context 'when there is a serious exception' do
    let(:error) { Exception }

    before do
      allow(client).to receive(:batch_poll).and_raise(error)
      allow(jobs_queue).to receive(:wait)
      allow(jobs_queue).to receive(:clear)
      allow(client).to receive(:reset)
      listener.call
    end

    it 'expect to run proper instrumentation' do
      Karafka.monitor.subscribe('error.occurred') do |event|
        expect(event.payload[:caller]).to eq(listener)
        expect(event.payload[:error]).to eq(error)
        expect(event.payload[:type]).to eq('connection.listener.fetch_loop.error')
      end
    end

    it 'expect to wait on the jobs queue' do
      expect(jobs_queue).to have_received(:wait).with(subscription_group.id).at_least(:once)
    end

    it 'expect to clear the jobs queue from any jobs from this subscription group' do
      expect(jobs_queue).to have_received(:clear).with(subscription_group.id)
    end

    it 'expect to reset the client' do
      expect(client).to have_received(:reset)
    end
  end

  describe '#start!' do
    before do
      allow(listener).to receive(:stopped?).and_return(stopped)
      allow(client).to receive(:reset)
      allow(status).to receive(:reset!)
      allow(status).to receive(:start!)
      allow(listener).to receive(:async_call)

      listener.start!
    end

    context 'when listener was stopped' do
      let(:stopped) { true }

      it 'expect to reset client and status before running in async again' do
        expect(client).to have_received(:reset)
        expect(status).to have_received(:reset!)
        expect(status).to have_received(:start!)
        expect(listener).to have_received(:async_call)
      end
    end

    context 'when listener was not stopped' do
      let(:stopped) { false }

      it 'expect not to reset and run async' do
        expect(client).not_to have_received(:reset)
        expect(status).not_to have_received(:reset!)
        expect(status).to have_received(:start!)
        expect(listener).to have_received(:async_call)
      end
    end
  end
end
