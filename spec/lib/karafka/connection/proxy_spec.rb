# frozen_string_literal: true

RSpec.describe_current do
  subject(:proxy) { described_class.new(consumer) }

  let(:consumer) { ::Rdkafka::Config.new(subscription_group.kafka).consumer }
  let(:subscription_group) { build(:routing_subscription_group) }
  let(:wrapped_object) { consumer }
  let(:all_down_error) { Rdkafka::RdkafkaError.new(-187) }

  after { consumer.close }

  describe '#initialize' do
    context 'when the given object is not a proxy' do
      it 'expect to wrap the provided object' do
        expect(proxy.wrapped).to eq(wrapped_object)
      end
    end

    context 'when the given object is a proxy' do
      let(:wrapped_object) { described_class.new(consumer) }

      it 'expect wrap the underlying object of the provided proxy' do
        expect(proxy.wrapped).to eq(wrapped_object.wrapped)
      end
    end
  end

  describe '#query_watermark_offsets' do
    let(:topic) { 'test_topic' }
    let(:partition) { 0 }
    let(:result) { [1, 2] }

    before do
      allow(wrapped_object)
        .to receive(:query_watermark_offsets)
        .with(topic, partition, 5_000)
        .and_return(result)
    end

    it 'expect to delegate to the wrapped object' do
      expect(proxy.query_watermark_offsets(topic, partition)).to eq(result)
    end

    context 'when an all_brokers_down error occurs' do
      before do
        allow(wrapped_object).to receive(:query_watermark_offsets).and_raise(all_down_error)
      end

      it 'retries up to the max attempts and then raises the error' do
        expect { proxy.query_watermark_offsets(topic, partition) }
          .to raise_error(Rdkafka::RdkafkaError, /all_brokers_down/)

        expect(wrapped_object)
          .to have_received(:query_watermark_offsets).exactly(3 + 1).times
      end
    end
  end

  describe '#offsets_for_times' do
    let(:tpl) { double }
    let(:result) { double }

    before do
      allow(wrapped_object).to receive(:offsets_for_times).with(tpl, 5_000).and_return(result)
    end

    it 'expect to delegate to the wrapped object' do
      expect(proxy.offsets_for_times(tpl)).to eq(result)
    end

    context 'when an all_brokers_down error occurs' do
      before { allow(wrapped_object).to receive(:offsets_for_times).and_raise(all_down_error) }

      it 'expect to retry up to the max attempts and then raises the error' do
        expect { proxy.offsets_for_times(tpl) }
          .to raise_error(Rdkafka::RdkafkaError, /all_brokers_down/)

        expect(wrapped_object)
          .to have_received(:offsets_for_times).exactly(3 + 1).times
      end
    end
  end
end
