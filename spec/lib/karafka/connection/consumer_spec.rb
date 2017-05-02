RSpec.describe Karafka::Connection::Consumer do
  subject(:consumer) { described_class.new }

  describe '#consume' do
    let(:topic) { rand.to_s }
    let(:raw_message_value) { rand }
    let(:message) { double }
    let(:builder) { Karafka::Routing::Router.new(nil) }
    let(:controller_instance) { instance_double(Karafka::BaseController, to_h: {}) }
    let(:raw_message) do
      instance_double(Kafka::FetchedMessage, value: raw_message_value, topic: topic)
    end

    context 'everything works well' do
      before do
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
      end

      it 'routes to a proper controller and schedule task' do
        expect { consumer.consume(raw_message) }.not_to raise_error
      end
    end

    context 'custom topic mapper' do
      let(:topic) { "prefix.#{mapped_topic}" }
      let(:mapped_topic) { rand.to_s }

      let(:custom_mapper) do
        ClassBuilder.build do
          def self.incoming(topic)
            topic.to_s.gsub('prefix.', '')
          end
        end
      end

      before do
        expect(Karafka::App.config)
          .to receive(:topic_mapper)
          .and_return(custom_mapper)

        expect(Karafka::Connection::Message)
          .to receive(:new)
          .with(mapped_topic, raw_message_value)
          .and_return(message)

        expect(Karafka::Routing::Router)
          .to receive(:new)
          .with(mapped_topic)
          .and_return(builder)

        expect(builder)
          .to receive(:build)
          .and_return(controller_instance)

        expect(controller_instance)
          .to receive(:params=)
          .with(message)

        expect(controller_instance)
          .to receive(:schedule)
      end

      it 'routes to a proper controller and schedule task' do
        expect { consumer.consume(raw_message) }.not_to raise_error
      end
    end

    context 'something goes wrong (exception is raised)' do
      [
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
            expect { consumer.consume(raw_message) }.not_to raise_error
          end
        end
      end
    end
  end
end
