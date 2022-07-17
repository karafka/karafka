# frozen_string_literal: true

require 'karafka/pro/loader'

RSpec.describe_current do
  subject(:loader) { described_class }

  context 'when we are loading active_job pro compoments' do
    let(:aj_defaults) { Karafka::App.config.internal.active_job.deep_dup.tap(&:configure) }
    let(:aj_config) { Karafka::App.config.internal.active_job }

    before { aj_defaults }

    after do
      aj_defaults.to_h.each do |key, value|
        Karafka::App.config.internal.active_job.public_send("#{key}=", value)
      end
    end

    context 'when we do not load pro' do
      it 'expect to use non-pro defaults' do
        expect(aj_config.dispatcher).to be_a(Karafka::ActiveJob::Dispatcher)
        expect(aj_config.job_options_contract).to be_a(Karafka::ActiveJob::JobOptionsContract)
      end
    end

    context 'when we run loader' do
      before { loader.setup(Karafka::App.config) }

      it 'expect to change active job components into pro' do
        expect(aj_config.dispatcher).to be_a(Karafka::Pro::ActiveJob::Dispatcher)
        expect(aj_config.job_options_contract).to be_a(Karafka::Pro::ActiveJob::JobOptionsContract)
      end
    end
  end
end
