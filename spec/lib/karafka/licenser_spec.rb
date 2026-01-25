# frozen_string_literal: true

RSpec.describe_current do
  subject(:prepare_and_verify) { described_class.prepare_and_verify(license_config) }

  let(:license_config) { Karafka::App.config.license.deep_dup.tap(&:configure) }

  context "when there is no license token" do
    before { license_config.token = false }

    it { expect { prepare_and_verify }.not_to raise_error }
    it { expect { prepare_and_verify }.not_to change(license_config, :entity) }
  end

  context "when license is loaded" do
    let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }
    let(:public_key_file) { Tempfile.new(["test_public_key", ".pem"]) }
    let(:entity_name) { "Test Entity" }
    let(:token_data) { { "entity" => entity_name } }
    let(:license_module) {
      Module.new {
        def self.token
        end
      }
    }

    before do
      public_key_file.write(rsa_key.public_key.to_pem)
      public_key_file.rewind

      stub_const("Karafka::License", license_module)
      stub_const("Karafka::Licenser::PUBLIC_KEY_LOCATION", public_key_file.path)
    end

    after do
      public_key_file.close
      public_key_file.unlink
    end

    context "when token is valid" do
      let(:encrypted_token) { rsa_key.private_encrypt(token_data.to_json) }
      let(:base64_token) { [encrypted_token].pack("m") }

      before { allow(license_module).to receive(:token).and_return(base64_token) }

      it "decrypts the token successfully" do
        expect { prepare_and_verify }.not_to raise_error
      end

      it "sets the entity from the decrypted token" do
        prepare_and_verify
        expect(license_config.entity).to eq(entity_name)
      end
    end

    context "when token has extra whitespace and newlines" do
      let(:encrypted_token) { rsa_key.private_encrypt(token_data.to_json) }
      let(:base64_token) { "  \n#{[encrypted_token].pack("m")}\n  " }

      before { allow(license_module).to receive(:token).and_return(base64_token) }

      it "decrypts the token successfully after formatting" do
        expect { prepare_and_verify }.not_to raise_error
      end

      it "sets the entity correctly" do
        prepare_and_verify
        expect(license_config.entity).to eq(entity_name)
      end
    end

    context "when token is invalid base64" do
      before { allow(license_module).to receive(:token).and_return("not-valid-base64!!!") }

      it "raises InvalidLicenseTokenError" do
        expect { prepare_and_verify }.to raise_error(Karafka::Errors::InvalidLicenseTokenError)
        expect(license_config.token).to be(false)
      end
    end

    context "when token is encrypted with a different key" do
      let(:other_key) { OpenSSL::PKey::RSA.new(2048) }
      let(:encrypted_token) { other_key.private_encrypt(token_data.to_json) }
      let(:base64_token) { [encrypted_token].pack("m") }

      before { allow(license_module).to receive(:token).and_return(base64_token) }

      it "raises InvalidLicenseTokenError" do
        expect { prepare_and_verify }.to raise_error(Karafka::Errors::InvalidLicenseTokenError)
        expect(license_config.token).to be(false)
      end
    end

    context "when token contains garbage data" do
      let(:base64_token) { ["random garbage data"].pack("m") }

      before { allow(license_module).to receive(:token).and_return(base64_token) }

      it "raises InvalidLicenseTokenError" do
        expect { prepare_and_verify }.to raise_error(Karafka::Errors::InvalidLicenseTokenError)
        expect(license_config.token).to be(false)
      end
    end
  end
end
