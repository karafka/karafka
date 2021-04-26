# frozen_string_literal: true

RSpec.describe_current do
  let(:jobs_queue) { Karafka::Processing::JobsQueue.new }

  context 'when creating workers batch' do
    let(:concurrency) { Karafka::App.config.concurrency }
    let(:thread_count) { -> { Thread.list.size } }

    it { expect { described_class.new(jobs_queue) }.to change(&thread_count).by(concurrency) }
  end
end
