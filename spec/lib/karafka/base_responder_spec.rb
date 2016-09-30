RSpec.describe Karafka::BaseResponder do
  let(:topic_name) { "topic#{rand(1000)}" }
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
        let(:topic_name) { rand.to_s }

        it { expect { responder_class }.to raise_error Karafka::Errors::InvalidTopicName }
      end
    end
  end

  context 'instance' do
    subject(:responder) { working_class.new }

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
        let(:kafka_message) { instance_double(::WaterDrop::Message) }

        it 'expect to register topic as used and message via waterdrop' do
          expect(::WaterDrop::Message)
            .to receive(:new).with(topic_name, input_data)
            .and_return(kafka_message)
          expect(kafka_message).to receive(:send!)
          responder.send(:respond_to, topic_name, input_data)
          expect(responder.instance_variable_get(:'@used_topics')).to eq [topic_name]
        end
      end

      context 'when we send non string data' do
        let(:input_data) { { rand => rand } }
        let(:kafka_message) { instance_double(::WaterDrop::Message) }

        it 'expect to cast to json, register topic as used and message via waterdrop' do
          expect(::WaterDrop::Message)
            .to receive(:new).with(topic_name, input_data.to_json)
            .and_return(kafka_message)
          expect(kafka_message).to receive(:send!)
          responder.send(:respond_to, topic_name, input_data)
          expect(responder.instance_variable_get(:'@used_topics')).to eq [topic_name]
        end
      end
    end

    describe '#validate!' do
      let(:usage_validator) { instance_double(Karafka::Responders::UsageValidator) }
      let(:registered_topics) { [rand, rand] }
      let(:used_topics) { [rand, rand] }

      before do
        working_class.topics = registered_topics
        responder.instance_variable_set(:'@used_topics', used_topics)

        expect(Karafka::Responders::UsageValidator).to receive(:new)
          .with(registered_topics, used_topics).and_return(usage_validator)
      end

      it 'expect to use UsageValidator to validate' do
        expect(usage_validator).to receive(:validate!)
        responder.send(:validate!)
      end
    end
  end
end
