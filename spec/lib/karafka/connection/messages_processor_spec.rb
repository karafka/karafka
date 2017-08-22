# frozen_string_literal: true

RSpec.describe Karafka::Connection::MessagesProcessor do
  subject(:processor) { described_class }

  describe '#process' do
    let(:group_id) { rand.to_s }
    let(:topic) { rand.to_s }
    let(:raw_message_value) { rand }
    let(:raw_message2) { raw_message1.dup }
    let(:raw_message1) do
      Kafka::FetchedMessage.new(
        value: raw_message_value,
        topic: topic,
        offset: 0,
        partition: 0,
        key: nil
      )
    end

    context 'batch_processing true' do
      let(:messages_batch) { [raw_message1, raw_message2] }
      let(:controller_instance) do
        instance_double(
          Karafka::BaseController,
          topic: instance_double(
            Karafka::Routing::Topic,
            batch_processing: true
          )
        )
      end

      context 'everything works well' do
        before do
          expect(Karafka::Routing::Router)
            .to receive(:build)
            .and_return(controller_instance)

          expect(controller_instance)
            .to receive(:params_batch=)
            .with([raw_message1, raw_message2])

          expect(controller_instance)
            .to receive(:schedule)
        end

        it 'routes to a proper controller and schedule task' do
          expect { processor.process(group_id, messages_batch) }.not_to raise_error
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
          expect(Karafka::App.config).to receive(:topic_mapper).and_return(custom_mapper)
          expect(Karafka::Routing::Router).to receive(:build).and_return(controller_instance)
          expect(controller_instance).to receive(:params_batch=).with([raw_message1, raw_message2])
          expect(controller_instance).to receive(:schedule)
        end

        it 'routes to a proper controller and schedule task' do
          expect { processor.process(group_id, messages_batch) }.not_to raise_error
        end
      end
    end

    context 'batch_processing false' do
      let(:messages_batch) { [raw_message1, raw_message2] }
      let(:controller_instance) do
        instance_double(
          Karafka::BaseController,
          topic: instance_double(
            Karafka::Routing::Topic,
            batch_processing: false
          )
        )
      end

      context 'everything works well' do
        before do
          expect(Karafka::Routing::Router)
            .to receive(:build)
            .and_return(controller_instance)

          expect(controller_instance)
            .to receive(:params_batch=)
            .with([raw_message1])

          expect(controller_instance)
            .to receive(:params_batch=)
            .with([raw_message2])

          expect(controller_instance)
            .to receive(:schedule).twice
        end

        it 'routes to a proper controller and schedule task' do
          expect { processor.process(group_id, messages_batch) }.not_to raise_error
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

          expect(Karafka::Routing::Router)
            .to receive(:build)
            .and_return(controller_instance)

          expect(controller_instance)
            .to receive(:params_batch=)
            .with([raw_message1])

          expect(controller_instance)
            .to receive(:params_batch=)
            .with([raw_message2])

          expect(controller_instance)
            .to receive(:schedule).twice
        end

        it 'routes to a proper controller and schedule task' do
          expect { processor.process(group_id, messages_batch) }.not_to raise_error
        end

        it 'dont corrupt the raw kafka message with topic remapping' do
          processor.process(group_id, messages_batch)
          expect(messages_batch.first.topic).to eq topic
        end
      end
    end
  end
end
