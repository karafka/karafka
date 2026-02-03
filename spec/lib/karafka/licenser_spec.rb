# frozen_string_literal: true

RSpec.describe_current do
  subject(:prepare_and_verify) { described_class.prepare_and_verify(license_config) }

  let(:license_config) { Karafka::App.config.license.deep_dup.tap(&:configure) }

  context "when there is no license token" do
    before do
      # Ensure License constant is not defined from previous tests
      # rubocop:disable RSpec/RemoveConst
      Karafka.send(:remove_const, :License) if Karafka.const_defined?(:License)
      # rubocop:enable RSpec/RemoveConst
      license_config.token = false
    end

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

  describe ".detect" do
    context "when License module is already fully defined by user" do
      let(:custom_token) { "custom-user-token" }
      let(:custom_version) { "1.0.0-custom" }
      let(:custom_license_module) do
        Module.new do
          def self.token
            "custom-user-token"
          end

          def self.version
            "1.0.0-custom"
          end
        end
      end

      before do
        stub_const("Karafka::License", custom_license_module)
      end

      it "does not override the user-defined License module" do
        result = described_class.detect { true }
        expect(result).to be(true)
        expect(Karafka::License.token).to eq(custom_token)
        expect(Karafka::License.version).to eq(custom_version)
      end

      it "does not attempt to require or load any gem" do
        expect(described_class).not_to receive(:safe_load_license)
        expect(described_class).not_to receive(:fallback_require_license)
        described_class.detect { true }
      end
    end

    context "when License module is not defined" do
      before do
        # Ensure License constant is not defined
        # rubocop:disable RSpec/RemoveConst
        Karafka.send(:remove_const, :License) if Karafka.const_defined?(:License)
        # rubocop:enable RSpec/RemoveConst
      end

      context "when karafka-license gem is not available" do
        before do
          allow(Gem::Specification).to receive(:find_by_name).with("karafka-license")
            .and_raise(Gem::MissingSpecError.new("karafka-license", Gem::Requirement.default))
          # Also stub require to raise LoadError for fallback
          allow(described_class).to receive(:require).with("karafka-license")
            .and_raise(LoadError.new("cannot load such file -- karafka-license"))
        end

        it "returns false when license cannot be loaded" do
          expect(described_class.detect { true }).to be(false)
        end

        it "does not yield the block" do
          yielded = false
          described_class.detect { yielded = true }
          expect(yielded).to be(false)
        end

        it "does not define License constant" do
          described_class.detect { true }
          expect(Karafka.const_defined?(:License)).to be(false)
        end
      end

      context "when safe_load_license succeeds" do
        let(:mock_spec) do
          double(gem_dir: "/fake/gem/path")
        end
        let(:license_content) { "fake-license-token" }
        let(:version_content) { "1.0.0" }

        before do
          allow(Gem::Specification).to receive(:find_by_name).with("karafka-license")
            .and_return(mock_spec)
          allow(File).to receive(:exist?).with("/fake/gem/path/lib/license.txt").and_return(true)
          allow(File).to receive(:read).with("/fake/gem/path/lib/license.txt")
            .and_return(license_content)
          allow(File).to receive(:read).with("/fake/gem/path/lib/version.txt")
            .and_return(version_content)
        end

        it "loads license successfully without requiring gem" do
          result = nil
          expect {
            result = described_class.detect { true }
          }.not_to raise_error

          expect(result).to be(true)
          expect(Karafka::License.token).to eq(license_content)
          expect(Karafka::License.version).to eq(version_content)
        end

        it "does not call require" do
          expect(described_class).not_to receive(:require)
          described_class.detect { true }
        end
      end
    end

    context "when License module exists but is missing methods" do
      let(:incomplete_license_module) { Module.new }

      before do
        stub_const("Karafka::License", incomplete_license_module)
        # Module exists but doesn't have token or version methods
      end

      it "attempts to load the license" do
        expect(described_class).to receive(:safe_load_license).and_call_original
        begin
          described_class.detect { true }
        rescue
          nil
        end
      end
    end
  end
end
