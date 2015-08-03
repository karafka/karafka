require 'spec_helper'

RSpec.describe Karafka::Aspects::AroundAspect do
  specify { expect(described_class).to be < Karafka::Aspects::BaseAspect }

  describe 'aspect hook' do
    let(:klass) do
      # Test class to hook aspect
      class AroundTest
        attr_accessor :instance_variable
        def run(*_args)
          @instance_variable = 5
          puts 'method_call'
        end

        def run_another(*_args)
          puts 'method_call'
          2390
        end

        self
      end
    end

    let(:delegate) { double }
    let(:formatter) { double }
    let(:before_message) do
      proc do
        @instance_variable ||= 98
        puts @instance_variable.inspect
      end
    end

    before do
      @instance = klass.new
      expect(Karafka::Aspects::Formatter).to receive(:new)
        .with(options, ['arg'], nil)
        .twice
        .and_return(formatter)

      allow(formatter).to receive(:message) { 'msg' }

      expect(Karafka::Event)
        .to receive(:new).with(options[:topic], formatter.message).twice.and_return(delegate)
      expect(delegate).to receive(:send!).twice
      expect(@instance).to receive(:puts).with('98').ordered
      expect(@instance).to receive(:puts).with('method_call').ordered
    end

    context 'message without parameter' do
      let(:after_message) do
        proc do
          @instance_variable ||= 98
          puts @instance_variable.inspect
        end
      end

      let(:options) do
        { method: :run,
          topic: 'topic',
          before_message: before_message,
          after_message: after_message
        }
      end
      it 'hooks to a given klass' do
        described_class.apply(klass, method: :run,
                                     topic: 'topic',
                                     before_message: before_message,
                                     after_message: after_message
                             )

        expect(@instance).to receive(:puts).with('5').ordered
        @instance.run('arg')
      end
    end

    context 'message with parameter' do
      let(:message_with_parameter) do
        ->(result) { puts result.inspect }
      end
      let(:options) do
        { method: :run_another,
          topic: 'topic2',
          before_message: before_message,
          after_message: message_with_parameter
        }
      end

      it 'hooks to given klass and get result of function execution' do
        described_class.apply(klass, method: :run_another,
                                     topic: 'topic2',
                                     before_message: before_message,
                                     after_message: message_with_parameter
                             )
        expect(message_with_parameter).to receive(:call).with(2390).ordered
        @instance.run_another('arg')
      end
    end
  end
end
