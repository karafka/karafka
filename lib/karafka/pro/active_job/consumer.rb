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

module Karafka
  module Pro
    module ActiveJob
      # Pro ActiveJob consumer that is suppose to handle long-running jobs as well as short
      # running jobs
      #
      # When in LRJ, it will pause a given partition forever and will resume its processing only
      # when all the jobs are done processing.
      #
      # It contains slightly better revocation warranties than the regular blocking consumer as
      # it can stop processing batch of jobs in the middle after the revocation.
      class Consumer < Karafka::ActiveJob::Consumer
        # Runs ActiveJob jobs processing and handles lrj if needed
        def consume
          messages.each(clean: true) do |message|
            # If for any reason we've lost this partition, not worth iterating over new messages
            # as they are no longer ours
            break if revoked?

            # We cannot early stop when running virtual partitions because the intermediate state
            # would force us not to commit the offsets. This would cause extensive
            # double-processing
            break if ::Karafka::App.stopping? && !topic.virtual_partitions?

            consume_job(message)

            # We can always mark because of the virtual offset management that we have in VPs
            mark_as_consumed(message)
          end
        end
      end
    end
  end
end
