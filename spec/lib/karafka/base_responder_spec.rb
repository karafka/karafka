RSpec.describe Karafka::BaseResponder do
  let(:topic_name) { 'topic_123.abc-xyz' }
  let(:input_data) { rand }

  let(:working_class) do
    name = topic_name
    ClassBuilder.inherit(described_class) do
      topic name
    end
  end

  context 'class' do
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

      context 'when we register invalid topic' do
        %w(
          & /31 ół !@
        ).each do |topic_name|
          let(:topic_name) { topic_name }

          it { expect { responder_class }.to raise_error(Karafka::Errors::InvalidTopicName) }
        end
      end
    end
  end

  context 'instance' do
    subject(:responder) { working_class.new(parser_class) }
    let(:parser_class) { Karafka::Parsers::Json }

    describe 'default responder' do
      subject(:responder) { working_class.new }
      let(:default_parser) { Karafka::Parsers::Json }

      it { expect(responder.instance_variable_get(:'@parser_class')).to eq default_parser }
    end

    describe '#call' do
      it 'expect to respond and validate' do
        expect(responder).to receive(:respond).with(input_data)
        expect(responder).to receive(:validate!)

        responder.call(input_data)
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
      let(:registered_topics) { [rand, rand] }
      let(:messages_buffer) { { rand => [rand], rand => [rand] } }

      before do
        working_class.topics = registered_topics
        responder.instance_variable_set(:'@messages_buffer', messages_buffer)

        expect(Karafka::Responders::UsageValidator).to receive(:new)
          .with(registered_topics, messages_buffer.keys).and_return(usage_validator)
      end

      it 'expect to use UsageValidator to validate' do
        expect(usage_validator).to receive(:validate!)
        responder.send(:validate!)
      end
    end

    describe '#deliver!' do
      before { responder.instance_variable_set(:'@messages_buffer', messages_buffer) }

      context 'when there is nothing to deliver' do
        let(:messages_buffer) { {} }

        it 'expect to do nothing' do
          expect(::WaterDrop::Message).not_to receive(:new)
          responder.send(:deliver!)
        end
      end

      context 'when there are messages to be delivered' do
        let(:messages_buffer) { { rand => [rand, rand] } }

        it 'expect to deliver them using waterdrop' do
          messages_buffer.each do |topic, data_elements|
            data_elements.each do |(data, options)|
              kafka_message = instance_double(::WaterDrop::Message)

              expect(::WaterDrop::Message)
                .to receive(:new).with(topic, data, options)
                .and_return(kafka_message)

              expect(kafka_message).to receive(:send!)
            end
          end

          responder.send(:deliver!)
        end
      end
    end
  end
end
