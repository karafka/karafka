# frozen_string_literal: true

RSpec.describe_current do
  subject(:job_class) do
    Class.new do
      extend ::Karafka::ActiveJob::JobExtensions
    end
  end

  context 'when we define job options' do
    subject(:option_setup) { job_class.karafka_options(args) }

    let(:args) { { 1 => 2 } }

    before do
      allow(Karafka::App.config.internal.active_job.job_options_contract)
        .to receive(:validate!)
        .with(args)
    end

    it 'expect to run the contract and assing' do
      expect(option_setup).to eq(args)
    end
  end
end
