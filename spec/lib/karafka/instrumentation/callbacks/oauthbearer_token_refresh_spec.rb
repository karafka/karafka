# frozen_string_literal: true

RSpec.describe_current do
  let(:bearer) { instance_double(Rdkafka::Consumer, name: 'TestBearer') }
  let(:rd_config) { instance_double(Rdkafka::Config) }
  let(:token_refresh) { described_class.new(bearer) }

  describe '#call' do
    before do
      allow(Karafka.monitor).to receive(:instrument)
    end

    context 'when the bearer name matches' do
      it 'calls Karafka.monitor.instrument with correct parameters' do
        token_refresh.call(rd_config, 'TestBearer')
        expect(Karafka.monitor).to have_received(:instrument).with(
          'oauthbearer.token_refresh',
          bearer: bearer,
          caller: token_refresh
        )
      end
    end

    context 'when the bearer name does not match' do
      it 'does not call Karafka.monitor.instrument' do
        token_refresh.call(rd_config, 'AnotherBearer')
        expect(Karafka.monitor).not_to have_received(:instrument)
      end
    end
  end
end
