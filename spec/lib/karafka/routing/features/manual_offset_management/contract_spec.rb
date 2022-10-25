# frozen_string_literal: true

RSpec.describe_current do
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      manual_offset_management: {
        active: true
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when active flag is not boolean' do
    before { config[:manual_offset_management][:active] = rand }

    it { expect(check).not_to be_success }
  end
end
