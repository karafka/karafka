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

# Karafka should not start if the token is invalid

failed_as_expected = false

ENV['KARAFKA_PRO_LICENSE_TOKEN'] = rand.to_s

begin
  setup_karafka
rescue Karafka::Errors::InvalidLicenseTokenError
  failed_as_expected = true
end

assert failed_as_expected
assert_equal false, Karafka.pro?

# No need to check visibility of anything because we raise exception
