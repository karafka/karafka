# frozen_string_literal: true

RSpec.describe_current do
  let(:queue) { described_class.new }
  let(:object) { Object.new }

  describe '#push and #pop' do
    it 'allows pushing and popping an object' do
      expect { queue.push(object) }.to change { queue.pop(timeout: 0) }.from(nil).to(object)
    end
  end

  describe '#pop' do
    context 'when queue is empty' do
      it 'returns nil when timeout is exceeded' do
        expect(queue.pop(timeout: 0.1)).to be_nil
      end

      it 'waits for an object to be pushed and pops it' do
        popped_object = nil
        thread = Thread.new { popped_object = queue.pop(timeout: 1) }

        # Ensure the thread is waiting
        sleep(0.1)
        queue.push(object)

        thread.join # wait for the thread to end
        expect(popped_object).to eq object
      end
    end

    context 'when the queue has elements' do
      before do
        queue.push(object)
      end

      it 'returns the object immediately' do
        expect(queue.pop(timeout: 1)).to eq object
      end
    end

    context 'when the queue is closed' do
      it 'returns nil immediately' do
        queue.close
        expect(queue.pop(timeout: 1)).to be_nil
      end
    end
  end

  describe '#close' do
    let(:threads) do
      Array.new(3) do
        Thread.new do
          queue.pop(timeout: 1)
        end
      end
    end

    it 'causes #pop to return nil' do
      queue.close
      expect(queue.pop(timeout: 1)).to be_nil
    end

    it 'wakes up all waiting threads with nil' do
      sleep(0.1) # give threads time to block
      queue.close
      threads.each(&:join) # wait for all threads to end

      threads.each { |thread| expect(thread.value).to be_nil }
    end
  end
end
