# frozen_string_literal: true

RSpec.describe Karafka::Schemas::ResponderUsage do
  subject(:schema) { described_class.new }

  let(:responder_usage) do
    {
      name: 'name',
      used_topics: [
        Karafka::Responders::Topic.new(
          'topic1',
          registered: true,
          usage_count: 1,
          serializer: -> {}
        )
      ],
      registered_topics: [
        Karafka::Responders::Topic.new(
          'topic1',
          registered: true,
          usage_count: 1,
          serializer: -> {}
        )
      ]
    }
  end

  context 'when we try to use unregistered topic' do
    before { responder_usage[:used_topics] = [rand.to_s] }

    it 'expect not to allow that' do
      expect(schema.call(responder_usage)).not_to be_success
    end
  end

  context 'when particular topics validations happen' do
    subject(:subschema) { Karafka::Schemas::ResponderUsageTopic.new }

    let(:name) { 'topic1' }
    let(:registered) { true }
    let(:usage_count) { 1 }
    let(:required) { true }
    let(:async) { false }
    let(:topic_data) do
      Karafka::Responders::Topic.new(
        name,
        registered: registered,
        required: required,
        async: async,
        serializer: -> {}
      ).to_h.merge!(usage_count: usage_count)
    end

    it { expect(subschema.call(topic_data)).to be_success }

    context 'when we validate name' do
      context 'when name is nil' do
        let(:name) { nil }

        it { expect(subschema.call(topic_data)).not_to be_success }
      end

      context 'when name is an invalid string' do
        let(:name) { '%^&*(' }

        it { expect(subschema.call(topic_data)).not_to be_success }
      end
    end

    context 'when we validate required field' do
      context 'when required is nil' do
        let(:required) { nil }

        it { expect(subschema.call(topic_data)).not_to be_success }
      end

      context 'when required is not a bool' do
        let(:required) { 2 }

        it { expect(subschema.call(topic_data)).not_to be_success }
      end
    end

    context 'when we validate async' do
      context 'when async is nil' do
        let(:async) { nil }

        it { expect(subschema.call(topic_data)).not_to be_success }
      end

      context 'when async is not a bool' do
        let(:async) { 2 }

        it { expect(subschema.call(topic_data)).not_to be_success }
      end
    end

    context 'when we didnt use required topic' do
      let(:required) { true }
      let(:usage_count) { 0 }

      it { expect(subschema.call(topic_data)).not_to be_success }
    end

    context 'when we did use required topic' do
      let(:required) { true }
      let(:usage_count) { 1 }

      it { expect(subschema.call(topic_data)).to be_success }
    end

    context 'when we didnt use required topic' do
      let(:required) { true }
      let(:usage_count) { 0 }

      it { expect(subschema.call(topic_data)).not_to be_success }
    end

    context 'when we didnt use optional topic' do
      let(:required) { false }
      let(:usage_count) { 2 }

      it { expect(subschema.call(topic_data)).to be_success }
    end

    context 'when we did use required topic' do
      let(:required) { true }
      let(:usage_count) { 1 }

      it { expect(subschema.call(topic_data)).to be_success }
    end
  end
end
