# frozen_string_literal: true

# When the license token is not below the public key modulus (it could not have been made with
# this key), setup should fail with InvalidLicenseTokenError on every Ruby engine

public_key = OpenSSL::PKey::RSA.new(
  File.read(File.join(Karafka.gem_root, "certs", "karafka-pro.pem"))
)

LICENSE_TOKEN = [public_key.n.to_s(2)].pack("m")

license = Module.new do
  def self.token
    LICENSE_TOKEN
  end

  def self.version
    "1.0.0"
  end
end

Karafka.const_set(:License, license)

guarded = []

begin
  setup_karafka(pro: false)
rescue Karafka::Errors::InvalidLicenseTokenError
  guarded << true
end

assert_equal [true], guarded
assert_equal false, Karafka::App.config.license.token
