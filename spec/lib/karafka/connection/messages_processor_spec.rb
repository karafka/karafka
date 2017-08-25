# frozen_string_literal: true

RSpec.describe Karafka::Connection::MessagesProcessor do
  subject(:processor) { described_class }

  let(:group_id) { consumer_group.id }
  let(:topic_id) { consumer_group.topics[0].name }
  let(:controller_instance) { consumer_group.topics[0].controller.new }
  let(:messages_batch) { [raw_message1, raw_message2] }
  let(:raw_message_value) { rand }
  let(:raw_message2) { raw_message1.dup }
  let(:raw_message1) do
    Kafka::FetchedMessage.new(
      value: raw_message_value,
      topic: topic_id,
      offset: 0,
      partition: 0,
      key: nil
    )
  end

  context 'batch_processing true' do
    before do
      expect(consumer_group.topics[0].controller)
        .to receive(:new).and_return(controller_instance)

      expect(controller_instance)
        .to receive(:params_batch=)
        .with([raw_message1, raw_message2])

      expect(controller_instance)
        .to receive(:call)
    end

    context 'everything works well' do
      let(:consumer_group) do
        Karafka::Routing::Builder.instance.draw do
          topic :topic_name1 do
            controller Class.new(Karafka::BaseController)
            persistent false
            batch_processing true
          end
        end

        Karafka::Routing::Builder.instance.last
      end

      before do
        expect(Karafka::Routing::Router)
          .to receive(:find)
          .with("#{group_id}_#{topic_id}")
          .and_return(consumer_group.topics[0])
      end

      it 'routes to a proper controller and call task' do
        expect { processor.process(group_id, messages_batch) }.not_to raise_error
      end
    end

    context 'mapped topic name' do
      let(:topic_id) { "prefix.#{consumer_group.topics[0].name}" }
      let(:consumer_group) do
        Karafka::Routing::Builder.instance.draw do
          topic :topic_name1 do
            controller Class.new(Karafka::BaseController)
            persistent false
            batch_processing true
          end
        end

        Karafka::Routing::Builder.instance.last
      end
      let(:custom_mapper) do
        ClassBuilder.build do
          def self.incoming(topic_name)
            topic_name.to_s.gsub('prefix.', '')
          end
        end
      end

      before do
        expect(Karafka::Routing::Router)
          .to receive(:find)
          .with("#{group_id}_#{consumer_group.topics[0].name}")
          .and_return(consumer_group.topics[0])
      end

      it 'expect to run with remaping' do
        expect(Karafka::App.config).to receive(:topic_mapper).and_return(custom_mapper)
        expect { processor.process(group_id, messages_batch) }.not_to raise_error
      end
    end
  end

  context 'batch_processing false' do
    before do
      expect(consumer_group.topics[0].controller)
        .to receive(:new).and_return(controller_instance)

      expect(controller_instance)
        .to receive(:params_batch=)
        .with([raw_message1])

      expect(controller_instance)
        .to receive(:params_batch=)
        .with([raw_message2])

      expect(controller_instance)
        .to receive(:call)
        .twice
    end

    context 'everything works well' do
      let(:consumer_group) do
        Karafka::Routing::Builder.instance.draw do
          topic :topic_name1 do
            controller Class.new(Karafka::BaseController)
            persistent false
            batch_processing false
          end
        end

        Karafka::Routing::Builder.instance.last
      end

      before do
        expect(Karafka::Routing::Router)
          .to receive(:find)
          .with("#{group_id}_#{topic_id}")
          .and_return(consumer_group.topics[0])
      end

      it 'routes to a proper controller and call task' do
        expect { processor.process(group_id, messages_batch) }.not_to raise_error
      end
    end

    context 'mapped topic name' do
      let(:topic_id) { "prefix.#{consumer_group.topics[0].name}" }
      let(:consumer_group) do
        Karafka::Routing::Builder.instance.draw do
          topic :topic_name1 do
            controller Class.new(Karafka::BaseController)
            persistent false
            batch_processing false
          end
        end

        Karafka::Routing::Builder.instance.last
      end
      let(:custom_mapper) do
        ClassBuilder.build do
          def self.incoming(topic_name)
            topic_name.to_s.gsub('prefix.', '')
          end
        end
      end

      before do
        expect(Karafka::Routing::Router)
          .to receive(:find)
          .with("#{group_id}_#{consumer_group.topics[0].name}")
          .and_return(consumer_group.topics[0])
      end

      it 'expect to run with remaping' do
        expect(Karafka::App.config).to receive(:topic_mapper).and_return(custom_mapper)
        expect { processor.process(group_id, messages_batch) }.not_to raise_error
      end
    end
  end
end
