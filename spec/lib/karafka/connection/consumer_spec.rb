require 'spec_helper'

RSpec.describe Karafka::Connection::Consumer do
  subject { described_class.new }

  describe '#consume' do
    let(:topic) { rand.to_s }
    let(:raw_message_value) { rand }
    let(:raw_message) { double(value: raw_message_value, topic: topic) }
    let(:message) { double }
    let(:builder) { Karafka::Routing::Router.new(nil) }
    let(:controller_instance) { double(to_h: {}) }

    context 'everything works well' do
      it 'routes to a proper controller and schedule task' do
        expect(Karafka::Connection::Message)
          .to receive(:new)
          .with(topic, raw_message_value)
          .and_return(message)

        expect(Karafka::Routing::Router)
          .to receive(:new)
          .with(topic)
          .and_return(builder)

        expect(builder)
          .to receive(:build)
          .and_return(controller_instance)

        expect(controller_instance)
          .to receive(:params=)
          .with(message)

        expect(controller_instance)
          .to receive(:schedule)

        subject.consume(raw_message)
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

            it 'notices and not reraise error' do
              expect { subject.consume(raw_message) }.not_to raise_error
            end
          end
        end
      end
    end
  end
end
