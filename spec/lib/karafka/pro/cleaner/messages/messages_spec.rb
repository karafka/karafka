# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:messages) { Karafka::Messages::Messages.new(batch, {}) }

  let(:message1) { build(:messages_message) }
  let(:message2) { build(:messages_message) }
  let(:batch) { [message1, message2] }

  # Module to simulate external library instrumentation (like DataDog)
  let(:instrumentation_module) do
    Module.new do
      def each(clean: false, &_block)
        @instrumentation_calls ||= []
        super(clean: clean) do |message|
          @instrumentation_calls << "before_#{message.object_id}"
          yield(message)
          @instrumentation_calls << "after_#{message.object_id}"
        end
      end

      def instrumentation_calls
        @instrumentation_calls ||= []
      end
    end
  end

  describe '#each' do
    context 'when not with clean' do
      before { messages.each {} }

      it 'expect not to have all messages cleaned' do
        expect(message1.cleaned?).to be(false)
        expect(message2.cleaned?).to be(false)
      end
    end

    context 'when with clean' do
      before { messages.each(clean: true) {} }

      it 'expect to have all messages cleaned' do
        expect(message1.cleaned?).to be(true)
        expect(message2.cleaned?).to be(true)
      end
    end

    context 'when external library prepends instrumentation (compatibility test)' do
      let(:instrumented_messages) do
        msg_instance = Karafka::Messages::Messages.new(batch, {})
        msg_instance.extend(instrumentation_module)
        msg_instance
      end

      let(:instr_calls) { instrumented_messages.instrumentation_calls }

      context 'without cleaning' do
        before { instrumented_messages.each { |msg| msg.payload } }

        it { expect(instr_calls.size).to eq(4) }
        it { expect(instr_calls).to include("before_#{message1.object_id}") }
        it { expect(instr_calls).to include("after_#{message1.object_id}") }
        it { expect(instr_calls).to include("before_#{message2.object_id}") }
        it { expect(instr_calls).to include("after_#{message2.object_id}") }
      end

      context 'with cleaning' do
        before { instrumented_messages.each(clean: true) { |msg| msg.payload } }

        it { expect(instr_calls.size).to eq(4) }
        it { expect(instr_calls).to include("before_#{message1.object_id}") }
        it { expect(instr_calls).to include("after_#{message1.object_id}") }
        it { expect(message1.cleaned?).to be(true) }
        it { expect(message2.cleaned?).to be(true) }
      end

      context 'with cleaning (per-message verification)' do
        it 'cleans each message after its individual processing, one by one' do
          processing_order = []

          # Track when we access each message during iteration
          messages.each(clean: true) do |msg|
            processing_order << "processing_#{msg.offset}"
            msg.payload # Process the message

            # When processing the second message, the first should already be cleaned
            next unless msg == message2

            begin
              message1.payload
              processing_order << 'first_still_accessible'
            rescue Karafka::Pro::Cleaner::Errors::MessageCleanedError
              processing_order << 'first_already_cleaned'
            end
          end

          # Verify that when processing message2, message1 was already cleaned
          expect(processing_order).to include('first_already_cleaned')
          expect(processing_order).to eq(
            [
              "processing_#{message1.offset}",
              "processing_#{message2.offset}",
              'first_already_cleaned'
            ]
          )
        end

        it 'cleans messages after consumer block finishes, not during consumer execution' do
          access_during_consumer = []

          messages.each(clean: true) do |msg|
            msg.payload # Process the message

            # Within consumer block, message should still be accessible
            # because clean! happens AFTER yield returns
            begin
              msg.payload
              access_during_consumer << :accessible
            rescue Karafka::Pro::Cleaner::Errors::MessageCleanedError
              access_during_consumer << :cleaned
            end
          end

          # During consumer execution, messages should be accessible
          expect(access_during_consumer).to eq(%i[accessible accessible])

          # But after each() finishes, messages should be cleaned
          expect(message1.cleaned?).to be(true)
          expect(message2.cleaned?).to be(true)
        end
      end
    end
  end
end
