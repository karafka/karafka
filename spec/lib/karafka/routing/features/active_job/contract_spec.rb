# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      active_job: {
        active: false
      },
      manual_offset_management: {
        active: true
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

  context 'when someone tries to use ActiveJob without manual offset management' do
    before do
      config[:active_job][:active] = true
      config[:manual_offset_management][:active] = false
    end

    it { expect(check).not_to be_success }
  end
end
