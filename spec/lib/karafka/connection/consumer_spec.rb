require 'spec_helper'

RSpec.describe Karafka::Connection::Consumer do
  let(:controller_class) do
    ClassBuilder.inherit(Karafka::BaseController) do
      self.group = rand
      self.topic = rand

      def perform
        self
      end
    end
  end

  subject { described_class.new }

  describe '#consume' do
    let(:raw_message_value) { rand }
    let(:raw_message) { double(value: raw_message_value) }
    let(:message) { double }
    let(:builder) { Karafka::Routing::Router.new(nil) }
    let(:controller_instance) { double }

    context 'everything works well' do
      it 'should route to a proper controller and schedule task' do
        expect(Karafka::Connection::Message)
          .to receive(:new)
          .with(controller_class.topic, raw_message_value)
          .and_return(message)

        expect(Karafka::Routing::Router)
          .to receive(:new)
          .with(message)
          .and_return(builder)

        expect(builder)
          .to receive(:build)
          .and_return(controller_instance)

        expect(controller_instance)
          .to receive(:schedule)

        subject.consume(controller_class, raw_message)
      end

      context 'something goes wrong (exception is raised)' do
        [
          ZK::Exceptions::OperationTimeOut,
          Poseidon::Connection::ConnectionFailedError,
          Exception
        ].each do |error|
          context "when #{error} happens" do
            before do
              # Lets silence exceptions printing
              expect(Karafka.monitor)
                .to receive(:notice_error)
                .with(described_class, error)

              expect(Karafka::Routing::Router)
                .to receive(:new)
                .and_raise(error)
            end

            it 'should notice and not reraise error' do
              expect { subject.consume(controller_class, raw_message) }.not_to raise_error
            end
          end
        end
      end
    end
  end
end
