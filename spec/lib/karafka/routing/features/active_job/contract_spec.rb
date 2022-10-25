# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      active_job: {
        active: false
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  # ActiveJob is loaded for specs, we check the non-loaded spec in the integrations suite
  context 'when its a topic tagged with active job usage and ActiveJob visible' do
    before { config[:active_job][:active] = true }

    it { expect(check).to be_success }
  end
end
