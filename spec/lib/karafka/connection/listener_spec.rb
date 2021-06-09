# frozen_string_literal: true

RSpec.describe_current do
  subject(:listener) { described_class.new(subscription_group, jobs_queue) }

  let(:subscription_group) { build(:routing_subscription_group, topics: [routing_topic]) }
  let(:jobs_queue) { Karafka::Processing::JobsQueue.new }
  let(:client) { Karafka::Connection::Client.new(subscription_group) }
  let(:routing_topic) { build(:routing_topic) }

  before do
    Karafka::Processing::WorkersBatch.new(jobs_queue)

    allow(client.class).to receive(:new).and_return(client)
    allow(Karafka::App).to receive(:stopping?).and_return(false, true)
    allow(client).to receive(:batch_poll).and_return([])
  end

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

    it 'expect client to commit offsets' do
      expect(client).to have_received(:commit_offsets).exactly(3).times
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
      Karafka.monitor.subscribe('connection.listener.fetch_loop.error') do |event|
        expect(event.payload[:caller]).to eq(listener)
        expect(event.payload[:error]).to eq(error)
      end
    end

    it 'expect to wait on the jobs queue' do
      expect(jobs_queue).to have_received(:wait).with(subscription_group.id)
    end

    it 'expect to clear the jobs queue from any jobs from this subscription group' do
      expect(jobs_queue).to have_received(:clear).with(subscription_group.id)
    end

    it 'expect to reset the client' do
      expect(client).to have_received(:reset)
    end
  end
end
