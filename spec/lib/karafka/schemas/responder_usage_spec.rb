# frozen_string_literal: true

RSpec.describe Karafka::Schemas::ResponderUsage do
  subject(:schema) { described_class }

  let(:responder_usage) do
    {
      name: 'name',
      used_topics: ['topic1'],
      registered_topics: ['topic1'],
      topics: [
        {
          name: 'topic1',
          multiple_usage: false,
          usage_count: 1,
          required: true
        }
      ]
    }
  end

  context 'config is valid' do
    it { expect(schema.call(responder_usage).success?).to be_truthy }
  end

  context 'used_topics validator' do
    context 'used_topics is not an array' do
      before { responder_usage[:used_topics] = 'invalid' }

      it { expect(schema.call(responder_usage).success?).to be_falsey }
    end
  end

  context 'registered_topics validator' do
    context 'registered_topics is nil' do
      before { responder_usage[:registered_topics] = nil }

      it { expect(schema.call(responder_usage).success?).to be_falsey }
    end

    context 'registered_topics is an empty array' do
      before { responder_usage[:registered_topics] = [] }

      it { expect(schema.call(responder_usage).success?).to be_falsey }
    end

    context 'registered_topics is not an array' do
      before { responder_usage[:registered_topics] = 'invalid' }

      it { expect(schema.call(responder_usage).success?).to be_falsey }
    end
  end

  context 'usage of unregistered topics' do
    before { responder_usage[:used_topics] = [rand.to_s] }

    it 'expect not to allow that' do
      expect(schema.call(responder_usage).success?).to be_falsey
    end
  end

  context 'particular topics validators' do
    context 'name validator' do
      context 'name is nil' do
        before { responder_usage[:topics][0][:name] = nil }

        it { expect(schema.call(responder_usage).success?).to be_falsey }
      end

      context 'name is not a string' do
        before { responder_usage[:topics][0][:name] = 2 }

        it { expect(schema.call(responder_usage).success?).to be_falsey }
      end

      context 'name is an invalid string' do
        before { responder_usage[:topics][0][:name] = '%^&*(' }

        it { expect(schema.call(responder_usage).success?).to be_falsey }
      end
    end

    context 'required validator' do
      context 'required is nil' do
        before { responder_usage[:topics][0][:required] = nil }

        it { expect(schema.call(responder_usage).success?).to be_falsey }
      end

      context 'required is not a bool' do
        before { responder_usage[:topics][0][:required] = 2 }

        it { expect(schema.call(responder_usage).success?).to be_falsey }
      end
    end

    context 'multiple_usage validator' do
      context 'multiple_usage is nil' do
        before { responder_usage[:topics][0][:multiple_usage] = nil }

        it { expect(schema.call(responder_usage).success?).to be_falsey }
      end

      context 'multiple_usage is not a bool' do
        before { responder_usage[:topics][0][:multiple_usage] = 2 }

        it { expect(schema.call(responder_usage).success?).to be_falsey }
      end
    end

    context 'when we didnt use required topic' do
      before do
        responder_usage[:topics][0][:required] = true
        responder_usage[:topics][0][:usage_count] = 0
      end

      it { expect(schema.call(responder_usage).success?).to be_falsey }
    end

    context 'when we did use required topic' do
      before do
        responder_usage[:topics][0][:required] = true
        responder_usage[:topics][0][:usage_count] = 1
      end

      it { expect(schema.call(responder_usage).success?).to be_truthy }
    end

    context 'when we didnt use required topic with multiple_usage' do
      before do
        responder_usage[:topics][0][:multiple_usage] = true
        responder_usage[:topics][0][:required] = true
        responder_usage[:topics][0][:usage_count] = 0
      end

      it { expect(schema.call(responder_usage).success?).to be_falsey }
    end

    context 'when we did use required topic with multiple_usage once' do
      before do
        responder_usage[:topics][0][:multiple_usage] = true
        responder_usage[:topics][0][:required] = true
        responder_usage[:topics][0][:usage_count] = 1
      end

      it { expect(schema.call(responder_usage).success?).to be_truthy }
    end

    context 'when we did use required topic with multiple_usage twice' do
      before do
        responder_usage[:topics][0][:multiple_usage] = true
        responder_usage[:topics][0][:required] = true
        responder_usage[:topics][0][:usage_count] = 2
      end

      it { expect(schema.call(responder_usage).success?).to be_truthy }
    end

    context 'when we didnt use optional topic with multiple_usage' do
      before do
        responder_usage[:topics][0][:multiple_usage] = true
        responder_usage[:topics][0][:required] = false
        responder_usage[:topics][0][:usage_count] = 0
      end

      it { expect(schema.call(responder_usage).success?).to be_truthy }
    end

    context 'when we did use required topic without multiple_usage once' do
      before do
        responder_usage[:topics][0][:multiple_usage] = false
        responder_usage[:topics][0][:usage_count] = 1
      end

      it { expect(schema.call(responder_usage).success?).to be_truthy }
    end

    context 'when we did use required topic without multiple_usage twice' do
      before do
        responder_usage[:topics][0][:multiple_usage] = false
        responder_usage[:topics][0][:usage_count] = 2
      end

      it { expect(schema.call(responder_usage).success?).to be_falsey }
    end
  end
end
