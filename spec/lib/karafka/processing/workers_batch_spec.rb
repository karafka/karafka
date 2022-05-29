# frozen_string_literal: true

RSpec.describe_current do
  let(:jobs_queue) { Karafka::Processing::JobsQueue.new }

  context 'when creating workers batch' do
    let(:concurrency) { Karafka::App.config.concurrency }

    it { expect(described_class.new(jobs_queue).size).to eq(concurrency) }
  end
end
