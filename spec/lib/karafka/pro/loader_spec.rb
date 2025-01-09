# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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

    context 'when we run pre_setup_all loader' do
      before do
        allow(::Karafka::Pro::Routing::Features::VirtualPartitions).to receive(:activate)
        allow(::Karafka::Pro::Routing::Features::LongRunningJob).to receive(:activate)

        loader.pre_setup_all(Karafka::App.config)
      end

      it 'expect to change active job components into pro' do
        expect(aj_config.dispatcher).to be_a(Karafka::Pro::ActiveJob::Dispatcher)
        expect(aj_config.job_options_contract).to be_a(Karafka::Pro::ActiveJob::JobOptionsContract)
      end
    end
  end
end
