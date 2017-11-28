# frozen_string_literal: true

RSpec.describe Karafka::BaseResponder do
  let(:topic_name) { 'topic_123.abc-xyz' }
  let(:input_data) { rand }

  let(:working_class) do
    name = topic_name
    ClassBuilder.inherit(described_class) do
      topic name
    end
  end

  context 'when we want to use class methods' do
    subject(:responder_class) { working_class }

    describe '.topic' do
      context 'when we register valid topic' do
        it 'expect to register topic in topics under proper name' do
          expect(responder_class.topics[topic_name].name).to eq topic_name
        end

        it 'expect to build a topic object' do
          expect(responder_class.topics[topic_name]).to be_a Karafka::Responders::Topic
        end
      end
    end

    describe '.call' do
      it 'expect to create instance and try to deliver' do
        # Since there is no #respond method, it will build an instance and raise this
        expect { responder_class.call(input_data) }.to raise_error NotImplementedError
      end
    end
  end

  context 'when we want to use instance methods' do
    subject(:responder) { working_class.new(parser_class) }

    let(:parser_class) { Karafka::Parsers::Json }

    describe 'default responder' do
      subject(:responder) { working_class.new }

      let(:default_parser) { Karafka::Parsers::Json }

      it { expect(responder.instance_variable_get(:'@parser_class')).to eq default_parser }
    end

    describe '#call' do
      context 'when execution goes with errors' do
        let(:expected_error) { Karafka::Errors::InvalidResponderUsage }

        it 'expect to respond and validate' do
          expect(responder).to receive(:respond).with(input_data)
          expect { responder.call(input_data) }.to raise_error(expected_error)
        end
      end

      context 'when execution goes without errors' do
        let(:working_class) do
          name = topic_name
          ClassBuilder.inherit(described_class) do
            topic name, required: false
          end
        end

        it 'expect to respond and validate' do
          expect(responder).to receive(:respond).with(input_data)
          expect { responder.call(input_data) }.not_to raise_error
        end
      end
    end

    describe '#respond' do
      it { expect { responder.send(:respond, input_data) }.to raise_error NotImplementedError }
    end

    describe '#respond_to' do
      context 'when we send a string data' do
        let(:input_data) { rand.to_s }

        it 'expect to expect to put string data into messages buffer' do
          responder.send(:respond_to, topic_name, input_data)
          expect(responder.messages_buffer).to eq(topic_name => [[input_data, {}]])
        end
      end

      context 'when we send non string data' do
        let(:input_data) { { rand => rand } }

        it 'expect to cast to json, and buffer in messages buffer' do
          responder.send(:respond_to, topic_name, input_data)
          expect(responder.messages_buffer).to eq(topic_name => [[input_data.to_json, {}]])
        end
      end
    end

    describe '#validate!' do
      let(:usage_validator) { instance_double(Karafka::Responders::UsageValidator) }
      let(:registered_topics) { {} }
      let(:messages_buffer) { { rand => [rand], rand => [rand] } }

      before do
        working_class.topics = registered_topics
        responder.instance_variable_set(:'@messages_buffer', messages_buffer)
      end

      it 'expect to use UsageValidator to validate' do
        expected_error = Karafka::Errors::InvalidResponderUsage
        expect { responder.send(:validate!) }.to raise_error(expected_error)
      end
    end

    describe '#deliver!' do
      before { responder.instance_variable_set(:'@messages_buffer', messages_buffer) }

      context 'when there is nothing to deliver' do
        let(:messages_buffer) { {} }

        it 'expect to do nothing' do
          expect(::WaterDrop::SyncProducer).not_to receive(:call)
          responder.send(:deliver!)
        end
      end

      context 'when there are messages to be delivered for sync producer' do
        let(:messages_buffer) { { rand => [[rand, {}]] } }

        after { responder.send(:deliver!) }

        it 'expect to deliver them using waterdrop' do
          messages_buffer.each do |topic, data_elements|
            data_elements.each do |data, options|
              expect(::WaterDrop::SyncProducer)
                .to receive(:call).with(data, options.merge(topic: topic))
            end
          end
        end
      end

      context 'when there are messages to be delivered for async producer' do
        let(:messages_buffer) { { rand => [[rand, { async: true }]] } }

        after { responder.send(:deliver!) }

        it 'expect to deliver them using waterdrop' do
          messages_buffer.each do |topic, data_elements|
            data_elements.each do |data, options|
              expect(::WaterDrop::SyncProducer)
                .not_to receive(:call)

              expect(::WaterDrop::AsyncProducer)
                .to receive(:call).with(data, options.merge(topic: topic))
            end
          end
        end
      end

      context 'when we have custom mapper delivery' do
        let(:mapped_topic) { "prefix.#{topic}" }
        let(:topic) { rand.to_s }
        let(:messages_buffer) { { topic => [[rand, {}]] } }
        let(:custom_mapper) do
          ClassBuilder.build do
            def self.outgoing(topic)
              "prefix.#{topic}"
            end
          end
        end

        before do
          allow(Karafka::App.config)
            .to receive(:topic_mapper)
            .and_return(custom_mapper)
        end

        after { responder.send(:deliver!) }

        it 'expect to deliver them to mapped topic' do
          messages_buffer.each_value do |data_elements|
            data_elements.each do |data, options|
              expect(::WaterDrop::SyncProducer)
                .to receive(:call).with(data, options.merge(topic: mapped_topic))
            end
          end
        end
      end
    end
  end
end
