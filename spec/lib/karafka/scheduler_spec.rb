# frozen_string_literal: true

RSpec.describe_current do
  subject(:scheduler) { described_class.new }

  let(:jobs_array) { [] }

  context 'when there are no messages' do
    it { expect { |block| scheduler.call(jobs_array, &block) }.not_to yield_control }
  end

  context 'when there are jobs' do
    let(:jobs_array) do
      [
        Karafka::Processing::Jobs::Consume.new(nil, []),
        Karafka::Processing::Jobs::Consume.new(nil, []),
        Karafka::Processing::Jobs::Consume.new(nil, []),
        Karafka::Processing::Jobs::Consume.new(nil, [])
      ]
    end

    let(:yielded) do
      data = []

      scheduler.call(jobs_array) do |job|
        data << job
      end

      data
    end

    it 'expect to yield them in the fifo order' do
      expect(yielded).to eq(jobs_array)
    end
  end
end
