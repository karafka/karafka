# frozen_string_literal: true

# This script verifies integrity of the Pro license

require 'digest'
require 'securerandom'

LICENSE_ID = ENV.fetch('KARAFKA_PRO_VERSION')
LICENSE_CHECKSUM = ENV.fetch('KARAFKA_PRO_LICENSE_CHECKSUM')

GEM_VERSION = "karafka-license-#{LICENSE_ID}"
CACHE_PATH = File.join(Gem.dir, "cache", "#{GEM_VERSION}.gem")

def c(c, txt)
  puts "\033[0;3#{c}m#{txt}\033[0m"
end

if File.exist?(CACHE_PATH)
  computed = Digest::SHA256.file(CACHE_PATH).hexdigest

  if computed == LICENSE_CHECKSUM
    c 2, "Checksum verification succeeded for: #{GEM_VERSION}"
  else
    c 1, "Expected checksum does not match the computed one."
    c 1, "Verification failed for: #{GEM_VERSION}"
    exit 1
  end
else
  c 3, "Could not find the following artefact: #{GEM_VERSION}"
  exit 2
end
