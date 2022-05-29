# frozen_string_literal: true

RSpec.describe_current do
  describe '#async_call' do
    subject(:async_executor) do
      Class.new do
        include ::Karafka::Helpers::Async

        attr_reader :thread_id

        def call
          @thread_id = Thread.current.object_id
        end
      end.new
    end

    # The easiest way to check it is to run the code and save object id
    it 'expect to run call async' do
      async_executor.async_call
      async_executor.join

      expect(async_executor.thread_id).not_to eq(Thread.current.object_id)
    end
  end
end
