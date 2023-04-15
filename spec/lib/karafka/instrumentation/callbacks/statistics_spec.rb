# frozen_string_literal: true

RSpec.describe_current do
  subject(:callback) do
    described_class.new(subscription_group_id, consumer_group_id, client_name)
  end

  let(:subscription_group_id) { SecureRandom.hex(6) }
  let(:consumer_group_id) { SecureRandom.hex(6) }
  let(:client_name) { SecureRandom.hex(6) }
  let(:monitor) { ::Karafka.monitor }

  describe '#call' do
    let(:changed) { [] }
    let(:statistics) { {} }

    before do
      monitor.subscribe('statistics.emitted') do |event|
        changed << event[:statistics]
      end

      callback.call(statistics)
    end

    context 'when emitted statistics refer different producer' do
      it 'expect not to emit them' do
        expect(changed).to be_empty
      end
    end

    context 'when emitted statistics refer to expected producer' do
      let(:statistics) { { 'name' => client_name } }

      it 'expects to emit them' do
        expect(changed).to eq([statistics])
      end
    end

    context 'when we emit more statistics' do
      before do
        5.times do |count|
          callback.call('msg_count' => count, 'name' => client_name)
        end
      end

      it { expect(changed.size).to eq(5) }

      it 'expect to decorate them' do
        # First is also decorated but wit no change
        expect(changed.first['msg_count_d']).to eq(0)
        expect(changed.last['msg_count_d']).to eq(1)
      end
    end
  end

  describe 'emitted event data format' do
    let(:events) { [] }
    let(:event) { events.first }
    let(:statistics) { { 'name' => client_name, 'val' => 1, 'str' => 1 } }

    before do
      monitor.subscribe('statistics.emitted') do |event|
        events << event
      end

      callback.call(statistics)
    end

    it { expect(event.id).to eq('statistics.emitted') }
    it { expect(event[:subscription_group_id]).to eq(subscription_group_id) }
    it { expect(event[:statistics]).to eq(statistics) }
    it { expect(event[:statistics]['val_d']).to eq(0) }
  end

  describe 'behavior on errors' do
    context 'when an error occurs in the call' do
      let(:events) { [] }
      let(:event) { events.first }
      let(:statistics) { { 'name' => client_name } }

      before do
        monitor.subscribe('statistics.emitted') do
          raise StandardError
        end

        monitor.subscribe('error.occurred') do |event|
          events << event
        end
      end

      it { expect { callback.call(statistics) }.not_to raise_error }

      it 'expect to catch it and pipe to the instrumentation errors' do
        callback.call(statistics)
        expect(events).not_to be_empty
      end
    end
  end
end
