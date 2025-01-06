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

  describe '#committed' do
    let(:result) { double }

    before do
      allow(wrapped_object).to receive(:committed).with(nil, 5_000).and_return(result)
    end

    it 'expect to delegate to the wrapped object' do
      expect(proxy.committed).to eq(result)
    end

    context 'when an all_brokers_down error occurs' do
      before { allow(wrapped_object).to receive(:committed).and_raise(all_down_error) }

      it 'expect to retry up to the max attempts and then raises the error' do
        expect { proxy.committed }
          .to raise_error(Rdkafka::RdkafkaError, /all_brokers_down/)

        expect(wrapped_object)
          .to have_received(:committed).exactly(3 + 1).times
      end
    end
  end

  describe '#store_offset' do
    let(:message) { instance_double(Karafka::Messages::Message) }
    let(:metadata) { 'metadata' }

    context 'when storing the offset is successful' do
      before do
        allow(wrapped_object).to receive(:store_offset).with(message, metadata).and_return(true)
      end

      it 'returns true' do
        expect(proxy.store_offset(message, metadata)).to be true
      end
    end

    context 'when an assignment_lost error occurs' do
      # Simulate assignment lost error code
      let(:assignment_lost_error) { Rdkafka::RdkafkaError.new(-142) }

      before do
        allow(wrapped_object)
          .to receive(:store_offset)
          .with(message, metadata).and_raise(assignment_lost_error)
      end

      it 'returns false' do
        expect(proxy.store_offset(message, metadata)).to be false
      end
    end

    context 'when a state error occurs' do
      # Simulate state error code
      let(:state_error) { Rdkafka::RdkafkaError.new(-172) }

      before do
        allow(wrapped_object)
          .to receive(:store_offset)
          .with(message, metadata)
          .and_raise(state_error)
      end

      it 'returns false' do
        expect(proxy.store_offset(message, metadata)).to be false
      end
    end

    context 'when another RdkafkaError occurs' do
      # Simulate an unspecified error code
      let(:other_error) { Rdkafka::RdkafkaError.new(-1) }

      before do
        allow(wrapped_object)
          .to receive(:store_offset)
          .with(message, metadata)
          .and_raise(other_error)
      end

      it 'raises the error' do
        expect { proxy.store_offset(message, metadata) }.to raise_error(Rdkafka::RdkafkaError)
      end
    end
  end

  describe '#commit_offsets' do
    context 'when committing offsets asynchronously' do
      before do
        allow(wrapped_object).to receive(:commit).with(nil, true).and_return(true)
      end

      it 'returns true' do
        expect(proxy.commit_offsets).to be true
      end
    end

    context 'when committing offsets synchronously' do
      before do
        allow(wrapped_object).to receive(:commit).with(nil, false).and_return(true)
      end

      it 'returns true' do
        expect(proxy.commit_offsets(async: false)).to be true
      end
    end

    context 'when an assignment_lost error occurs' do
      let(:error) { Rdkafka::RdkafkaError.new(-142) }

      before do
        allow(wrapped_object).to receive(:commit).and_raise(error)
      end

      it 'returns false' do
        expect(proxy.commit_offsets).to be false
      end
    end

    context 'when an unknown_member_id error occurs' do
      let(:error) { Rdkafka::RdkafkaError.new(25) }

      before do
        allow(wrapped_object).to receive(:commit).and_raise(error)
      end

      it 'returns false' do
        expect(proxy.commit_offsets).to be false
      end
    end

    context 'when a no_offset error occurs' do
      let(:error) { Rdkafka::RdkafkaError.new(-168) }

      before do
        allow(wrapped_object).to receive(:commit).and_raise(error)
      end

      it 'returns true' do
        expect(proxy.commit_offsets).to be true
      end
    end

    context 'when a coordinator_load_in_progress error occurs' do
      let(:error) { Rdkafka::RdkafkaError.new(14) }

      before do
        attempts = 0
        allow(wrapped_object).to receive(:commit) do
          attempts += 1

          raise error if attempts == 1

          true # Simulates success on retry
        end
      end

      it 'retries once and then succeeds' do
        expect(proxy.commit_offsets).to be true
        expect(wrapped_object).to have_received(:commit).twice
      end
    end

    context 'when another RdkafkaError occurs' do
      let(:other_error) { Rdkafka::RdkafkaError.new(13) }

      before do
        allow(wrapped_object).to receive(:commit).and_raise(other_error)
      end

      it 'raises the error' do
        expect { proxy.commit_offsets }.to raise_error(Rdkafka::RdkafkaError)
      end
    end
  end
end
