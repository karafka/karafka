# frozen_string_literal: true

RSpec.describe_current do
  subject(:batch) { described_class.new(jobs_queue, scheduler) }

  let(:jobs_queue) { Karafka::Processing::JobsQueue.new }
  let(:scheduler) { Karafka::Processing::Scheduler.new(jobs_queue) }
  let(:consumer_group) { build(:routing_consumer_group) }
  let(:subscription_group) { build(:routing_subscription_group) }

  after { batch.each(&:shutdown) }

  describe '#each' do
    before do
      allow(Karafka::App).to receive(:subscription_groups).and_return(
        consumer_group => [subscription_group]
      )
    end

    it 'expect to yield each listener' do
      expect(batch).to all be_a(Karafka::Connection::Listener)
    end
  end
end
