# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Run the verification script post install to make sure it works as expected

cmd = <<~CMD
  MODE=after \
  KARAFKA_PRO_USERNAME='#{ENV['KARAFKA_PRO_USERNAME']}' \
  KARAFKA_PRO_PASSWORD='#{ENV['KARAFKA_PRO_PASSWORD']}' \
  KARAFKA_PRO_VERSION='#{ENV['KARAFKA_PRO_VERSION']}' \
  KARAFKA_PRO_LICENSE_CHECKSUM='#{ENV['KARAFKA_PRO_LICENSE_CHECKSUM']}' \
  #{ENV['KARAFKA_GEM_DIR']}/bin/verify_license_integrity
CMD

result = `#{cmd}`

exit 1 unless result.include?('verification result: Success')
