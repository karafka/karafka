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

# When there is a misconfiguration of karafka options on ActiveJob job class, it should raise an
# error

setup_karafka

setup_active_job

def handle
  yield
  DT[0] << false
rescue Karafka::Errors::InvalidConfigurationError
  DT[0] << true
end

Job = Class.new(ActiveJob::Base)

class Partitioner
  def call(_job)
    rand
  end
end

NotPartitioner = Class.new

handle { Job.karafka_options(dispatch_method: :na) }
handle { Job.karafka_options(dispatch_method: :produce_async) }
handle { Job.karafka_options(dispatch_method: rand) }
handle { Job.karafka_options(partitioner: rand) }
handle { Job.karafka_options(partitioner: ->(job) { job.job_id }) }
handle { Job.karafka_options(partitioner: Partitioner.new) }
handle { Job.karafka_options(partitioner: NotPartitioner.new) }

assert DT[0][0]
assert_equal false, DT[0][1]
assert DT[0][2]
assert DT[0][3]
assert_equal false, DT[0][4]
assert_equal false, DT[0][5]
assert DT[0][6]
