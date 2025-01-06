# frozen_string_literal: true

RSpec.describe_current do
  subject(:consumer) { described_class.new }

  let(:executor) { Karafka::Pro::RecurringTasks::Executor.new }
  let(:messages) { [instance_double(Karafka::Messages::Message, payload: payload, offset: 1)] }
  let(:payload) { { type: 'schedule', schedule_version: '1.0.0' } }
  let(:topic) { instance_double(Karafka::Routing::Topic, name: 'topic_name') }
  let(:partition) { 0 }
  let(:expected_error) { Karafka::Pro::RecurringTasks::Errors::IncompatibleScheduleError }

  before do
    allow(Karafka::Pro::RecurringTasks::Executor).to receive(:new).and_return(executor)

    allow(consumer).to receive_messages(
      messages: messages,
      topic: topic,
      partition: partition,
      mark_as_consumed: nil,
      seek: nil,
      eofed?: false
    )

    allow(executor).to receive_messages(
      incompatible?: false,
      replaying?: false,
      update_state: nil,
      apply_command: nil,
      call: nil,
      replay: nil
    )
  end

  describe '#initialize' do
    it 'initializes an executor' do
      expect(consumer.instance_variable_get(:@executor)).to eq(executor)
    end
  end

  describe '#consume' do
    context 'when the schedule is incompatible' do
      before { allow(executor).to receive(:incompatible?).and_return(true) }

      it 'raises an IncompatibleScheduleError' do
        expect { consumer.consume }.to raise_error(expected_error)
      end
    end

    context 'when the message type is "schedule"' do
      context 'when executor is replaying' do
        before { allow(executor).to receive(:replaying?).and_return(true) }

        it 'updates the executor state' do
          consumer.consume
          expect(executor).to have_received(:update_state).with(payload)
        end

        context 'when the message offset is zero' do
          before { allow(messages.first).to receive(:offset).and_return(0) }

          it 'does not mark as consumed' do
            consumer.consume
            expect(consumer).not_to have_received(:mark_as_consumed)
          end
        end

        context 'when the message offset is greater than zero' do
          it 'marks the previous offset as consumed' do
            consumer.consume
            expect(consumer).to have_received(:mark_as_consumed).with(
              an_instance_of(Karafka::Messages::Seek)
            )
          end
        end
      end
    end

    context 'when the message type is "command"' do
      let(:payload) { { type: 'command', command: { name: 'disable' }, task: { id: 'task1' } } }

      it 'applies the command using the executor' do
        consumer.consume
        expect(executor).to have_received(:apply_command).with(payload)
      end

      context 'when executor is not replaying' do
        it 'executes the executor' do
          consumer.consume
          expect(executor).to have_received(:call)
        end
      end
    end

    context 'when the message type is unsupported' do
      let(:payload) { { type: 'unsupported_type' } }

      it 'raises an UnsupportedCaseError' do
        expect { consumer.consume }.to raise_error(Karafka::Errors::UnsupportedCaseError)
      end
    end

    context 'when eof is reached' do
      before { allow(consumer).to receive(:eofed?).and_return(true) }

      it 'calls eofed method' do
        allow(consumer).to receive(:eofed)
        consumer.consume
        expect(consumer).to have_received(:eofed)
      end
    end
  end

  describe '#eofed' do
    context 'when executor is replaying' do
      before { allow(executor).to receive(:replaying?).and_return(true) }

      it 'replays the executor' do
        consumer.eofed
        expect(executor).to have_received(:replay)
      end
    end

    context 'when executor is not replaying' do
      it 'does nothing' do
        consumer.eofed
        expect(executor).not_to have_received(:replay)
      end
    end
  end

  describe '#tick' do
    context 'when executor is replaying' do
      before { allow(executor).to receive(:replaying?).and_return(true) }

      it 'does not execute the executor' do
        consumer.tick
        expect(executor).not_to have_received(:call)
      end
    end

    context 'when the schedule is incompatible' do
      before { allow(executor).to receive(:incompatible?).and_return(true) }

      context 'when there are no messages' do
        before { allow(consumer).to receive(:messages).and_return([]) }

        it 'raises an IncompatibleScheduleError' do
          expect { consumer.tick }.to raise_error(expected_error)
        end
      end

      context 'when there are messages' do
        it 'seeks to the previous offset' do
          consumer.tick
          expect(consumer).to have_received(:seek).with(messages.last.offset - 1)
        end
      end
    end

    context 'when executor is not replaying and the schedule is compatible' do
      it 'executes the executor' do
        consumer.tick
        expect(executor).to have_received(:call)
      end
    end
  end
end
