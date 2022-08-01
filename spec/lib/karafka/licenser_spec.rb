# frozen_string_literal: true

RSpec.describe_current do
  subject(:prepare_and_verify) { described_class.new.prepare_and_verify(license_config) }

  let(:license_config) { Karafka::App.config.license.deep_dup.tap(&:configure) }

  context 'when there is no license token' do
    before { license_config.token = false }

    it { expect { prepare_and_verify }.not_to raise_error }
    it { expect { prepare_and_verify }.not_to change(license_config, :entity) }
  end

  context 'when token is invalid' do
    before { license_config.token = rand.to_s }

    it { expect { prepare_and_verify }.to raise_error(Karafka::Errors::InvalidLicenseTokenError) }
  end
end
