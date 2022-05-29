# frozen_string_literal: true

RSpec.describe_current do
  subject(:batch) { described_class.new(jobs_queue) }

  let(:jobs_queue) { Karafka::Processing::JobsQueue.new }
  let(:subscription_group) { build(:routing_subscription_group) }

  describe '#each' do
    before do
      allow(Karafka::App).to receive(:subscription_groups).and_return([subscription_group])
    end

    it 'expect to yield each listener' do
      batch.each do |listener|
        expect(listener).to be_a(Karafka::Connection::Listener)
      end
    end
  end
end
