# frozen_string_literal: true

RSpec.describe Karafka::Schemas::ResponderUsage do
  subject(:schema) { described_class }

  let(:responder_usage) do
    {
      name: 'name',
      used_topics: [
        Karafka::Responders::Topic.new(
          'topic1',
          registered: true,
          usage_count: 1
        )
      ],
      registered_topics: [
        Karafka::Responders::Topic.new(
          'topic1',
          registered: true,
          usage_count: 1
        )
      ]
    }
  end

  context 'usage of unregistered topics' do
    before { responder_usage[:used_topics] = [rand.to_s] }

    it 'expect not to allow that' do
      expect(schema.call(responder_usage)).not_to be_success
    end
  end

  context 'particular topics validators' do
    subject(:subschema) { Karafka::Schemas::ResponderUsageTopic }

    let(:name) { 'topic1' }
    let(:registered) { true }
    let(:usage_count) { 1 }
    let(:multiple_usage) { false }
    let(:required) { true }
    let(:topic_data) do
      Karafka::Responders::Topic.new(
        name,
        registered: registered,
        required: required,
        multiple_usage: multiple_usage
      ).to_h.merge!(usage_count: usage_count)
    end

    it { expect(subschema.call(topic_data)).to be_success }

    context 'name validator' do
      context 'name is nil' do
        let(:name) { nil }

        it { expect(subschema.call(topic_data)).not_to be_success }
      end

      context 'name is an invalid string' do
        let(:name) { '%^&*(' }

        it { expect(subschema.call(topic_data)).not_to be_success }
      end
    end

    context 'required validator' do
      context 'required is nil' do
        let(:required) { nil }

        it { expect(subschema.call(topic_data)).not_to be_success }
      end

      context 'required is not a bool' do
        let(:required) { 2 }

        it { expect(subschema.call(topic_data)).not_to be_success }
      end
    end

    context 'multiple_usage validator' do
      context 'multiple_usage is not a bool' do
        let(:multiple_usage) { 2 }

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

    context 'when we didnt use required topic with multiple_usage' do
      let(:required) { true }
      let(:usage_count) { 0 }
      let(:multiple_usage) { true }

      it { expect(subschema.call(topic_data)).not_to be_success }
    end

    context 'when we did use required topic with multiple_usage once' do
      let(:required) { true }
      let(:usage_count) { 1 }
      let(:multiple_usage) { true }

      it { expect(subschema.call(topic_data)).to be_success }
    end

    context 'when we did use required topic with multiple_usage twice' do
      let(:required) { true }
      let(:usage_count) { 2 }
      let(:multiple_usage) { true }

      it { expect(subschema.call(topic_data)).to be_success }
    end

    context 'when we didnt use optional topic with multiple_usage' do
      let(:required) { false }
      let(:usage_count) { 2 }
      let(:multiple_usage) { true }

      it { expect(subschema.call(topic_data)).to be_success }
    end

    context 'when we did use required topic without multiple_usage once' do
      let(:required) { true }
      let(:usage_count) { 1 }
      let(:multiple_usage) { false }

      it { expect(subschema.call(topic_data)).to be_success }
    end

    context 'when we did use required topic without multiple_usage twice' do
      let(:required) { true }
      let(:usage_count) { 2 }
      let(:multiple_usage) { false }

      it { expect(subschema.call(topic_data)).not_to be_success }
    end
  end
end
