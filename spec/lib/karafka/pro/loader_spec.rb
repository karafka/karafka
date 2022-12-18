# frozen_string_literal: true

RSpec.describe_current do
  subject(:loader) { described_class }

  before do
    # We do not want to load extensions as they would leak into other specs
    allow(loader).to receive(:load_routing_extensions)
  end

  context 'when we are loading active_job pro compoments' do
    let(:aj_defaults) { Karafka::App.config.internal.active_job.deep_dup.tap(&:configure) }
    let(:aj_config) { Karafka::App.config.internal.active_job }

    before { aj_defaults }

    after do
      aj_defaults.to_h.each do |key, value|
        Karafka::App.config.internal.active_job.public_send("#{key}=", value)
      end
    end

    context 'when we run pre_setup loader' do
      before do
        allow(::Karafka::Pro::Routing::Features::VirtualPartitions).to receive(:activate)
        allow(::Karafka::Pro::Routing::Features::LongRunningJob).to receive(:activate)

        loader.pre_setup(Karafka::App.config)
      end

      it 'expect to change active job components into pro' do
        expect(aj_config.dispatcher).to be_a(Karafka::Pro::ActiveJob::Dispatcher)
        expect(aj_config.job_options_contract).to be_a(Karafka::Pro::ActiveJob::JobOptionsContract)
      end

      it 'expect to load pro routing features' do
        expect(::Karafka::Pro::Routing::Features::VirtualPartitions).to have_received(:activate)
        expect(::Karafka::Pro::Routing::Features::LongRunningJob).to have_received(:activate)
      end
    end
  end
end
