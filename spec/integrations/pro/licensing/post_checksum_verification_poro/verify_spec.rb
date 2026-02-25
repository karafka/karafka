# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Run the verification script post install to make sure it works as expected

cmd = <<~CMD
  MODE=after \
  KARAFKA_PRO_USERNAME='#{ENV.fetch("KARAFKA_PRO_USERNAME", nil)}' \
  KARAFKA_PRO_PASSWORD='#{ENV.fetch("KARAFKA_PRO_PASSWORD", nil)}' \
  KARAFKA_PRO_VERSION='#{ENV.fetch("KARAFKA_PRO_VERSION", nil)}' \
  KARAFKA_PRO_LICENSE_CHECKSUM='#{ENV.fetch("KARAFKA_PRO_LICENSE_CHECKSUM", nil)}' \
  #{ENV.fetch("KARAFKA_GEM_DIR", nil)}/bin/verify_license_integrity
CMD

result = `#{cmd}`

exit 1 unless result.include?("verification result: Success")
