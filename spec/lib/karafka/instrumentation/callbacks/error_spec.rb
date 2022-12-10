# frozen_string_literal: true

RSpec.describe_current do
  subject(:callback) do
    described_class.new(
      subscription_group_id,
      consumer_group_id,
      client_name,
      monitor
    )
  end

  let(:subscription_group_id) { SecureRandom.hex(6) }
  let(:consumer_group_id) { SecureRandom.hex(6) }
  let(:client_name) { SecureRandom.hex(6) }
  let(:monitor) { ::Karafka::Instrumentation::Monitor.new }
  let(:error) { ::Rdkafka::RdkafkaError.new(1, []) }

  describe '#call' do
    let(:changed) { [] }

    before do
      monitor.subscribe('error.occurred') do |event|
        changed << event[:error]
      end

      callback.call(client_name, error)
    end

    context 'when emitted error refer different producer' do
      subject(:callback) do
        described_class.new(subscription_group_id, consumer_group_id, 'other', monitor)
      end

      it 'expect not to emit them' do
        expect(changed).to be_empty
      end
    end

    context 'when emitted error refer to expected producer' do
      it 'expects to emit them' do
        expect(changed).to eq([error])
      end
    end
  end

  describe 'emitted event data format' do
    let(:changed) { [] }
    let(:event) { changed.first }

    before do
      monitor.subscribe('error.occurred') do |stat|
        changed << stat
      end

      callback.call(client_name, error)
    end

    it { expect(event.id).to eq('error.occurred') }
    it { expect(event[:subscription_group_id]).to eq(subscription_group_id) }
    it { expect(event[:consumer_group_id]).to eq(consumer_group_id) }
    it { expect(event[:error]).to eq(error) }
  end
end
