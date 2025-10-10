# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Run the verification script post install to make sure it works as expected

cmd = <<~CMD
  MODE=after \
  KARAFKA_PRO_USERNAME='#{ENV.fetch('KARAFKA_PRO_USERNAME', nil)}' \
  KARAFKA_PRO_PASSWORD='#{ENV.fetch('KARAFKA_PRO_PASSWORD', nil)}' \
  KARAFKA_PRO_VERSION='#{ENV.fetch('KARAFKA_PRO_VERSION', nil)}' \
  KARAFKA_PRO_LICENSE_CHECKSUM='#{ENV.fetch('KARAFKA_PRO_LICENSE_CHECKSUM', nil)}' \
  #{ENV.fetch('KARAFKA_GEM_DIR', nil)}/bin/verify_license_integrity
CMD

result = `#{cmd}`

exit 1 unless result.include?('verification result: Success')
