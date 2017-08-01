# frozen_string_literal: true

RSpec.describe Karafka::Connection::MessageProcessor do
  subject(:processor) { described_class }

  describe '#process' do
    let(:group_id) { rand.to_s }
    let(:topic) { rand.to_s }
    let(:raw_message_value) { rand }
    let(:message) { double }
    let(:controller_instance) { instance_double(Karafka::BaseController) }
    let(:raw_message) do
      instance_double(
        Kafka::FetchedMessage,
        value: raw_message_value,
        topic: topic,
        offset: 0,
        partition: 0,
        key: nil
      )
    end

    context 'everything works well' do
      before do
        expect(Karafka::Connection::Message)
          .to receive(:new)
          .with(topic, raw_message)
          .and_return(message)

        expect(Karafka::Routing::Router)
          .to receive(:build)
          .and_return(controller_instance)

        expect(controller_instance)
          .to receive(:params=)
          .with(message)

        expect(controller_instance)
          .to receive(:schedule)
      end

      it 'routes to a proper controller and schedule task' do
        expect { processor.process(group_id, raw_message) }.not_to raise_error
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
          .with(mapped_topic, raw_message)
          .and_return(message)

        expect(Karafka::Routing::Router)
          .to receive(:build)
          .and_return(controller_instance)

        expect(controller_instance)
          .to receive(:params=)
          .with(message)

        expect(controller_instance)
          .to receive(:schedule)
      end

      it 'routes to a proper controller and schedule task' do
        expect { processor.process(group_id, raw_message) }.not_to raise_error
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
              .to receive(:build)
              .and_raise(error)
          end

          it 'notices and not reraise error' do
            expect { processor.process(group_id, raw_message) }.not_to raise_error
          end
        end
      end
    end
  end
end
