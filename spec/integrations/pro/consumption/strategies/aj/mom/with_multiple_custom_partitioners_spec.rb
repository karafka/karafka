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

# Karafka should use different partitioners and karafka options for jobs and not mutate in between

setup_karafka
setup_active_job

class Default < ActiveJob::Base
end

class JobA < ActiveJob::Base
  karafka_options(
    partitioner: ->(_) { 'a' },
    dispatch_method: :produce_sync
  )

  def perform; end
end

class JobB < ActiveJob::Base
  karafka_options(
    partitioner: ->(_) { 'b' },
    dispatch_method: :produce_sync
  )

  def perform; end
end

class JobC < JobA
  # This should replace only dispatch method and use parent partitioner
  karafka_options(
    dispatch_method: :produce_async
  )
end

assert_equal Default.karafka_options[:dispatch_method], nil
assert_equal JobA.karafka_options[:dispatch_method], :produce_sync
assert_equal JobB.karafka_options[:dispatch_method], :produce_sync
assert_equal JobC.karafka_options[:dispatch_method], :produce_async

assert Default.karafka_options != JobA
assert Default.karafka_options != JobB
assert Default.karafka_options != JobC
assert JobA.karafka_options != JobB.karafka_options
assert JobA.karafka_options != JobC.karafka_options
assert_equal JobA.karafka_options[:partitioner], JobC.karafka_options[:partitioner]
