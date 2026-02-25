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
    module Processing
      # Pro jobs builder that supports lrj
      class JobsBuilder < Karafka::Processing::JobsBuilder
        # @param executor [Karafka::Pro::Processing::Executor]
        def idle(executor)
          Karafka::Processing::Jobs::Idle.new(executor)
        end

        # @param executor [Karafka::Pro::Processing::Executor]
        # @param messages [Karafka::Messages::Messages] messages batch to be consumed
        # @return [Karafka::Processing::Jobs::Consume] blocking job
        # @return [Karafka::Pro::Processing::Jobs::ConsumeNonBlocking] non blocking for lrj
        def consume(executor, messages)
          if executor.topic.long_running_job?
            Jobs::ConsumeNonBlocking.new(executor, messages)
          else
            super
          end
        end

        # @param executor [Karafka::Pro::Processing::Executor]
        # @return [Karafka::Processing::Jobs::Eofed] eofed job for non LRJ
        # @return [Karafka::Processing::Jobs::EofedBlocking] eofed job that is
        #   non-blocking, so when revocation job is scheduled for LRJ it also will not block
        def eofed(executor)
          if executor.topic.long_running_job?
            Jobs::EofedNonBlocking.new(executor)
          else
            super
          end
        end

        # @param executor [Karafka::Pro::Processing::Executor]
        # @return [Karafka::Processing::Jobs::Revoked] revocation job for non LRJ
        # @return [Karafka::Processing::Jobs::RevokedNonBlocking] revocation job that is
        #   non-blocking, so when revocation job is scheduled for LRJ it also will not block
        def revoked(executor)
          if executor.topic.long_running_job?
            Jobs::RevokedNonBlocking.new(executor)
          else
            super
          end
        end

        # @param executor [Karafka::Pro::Processing::Executor]
        # @return [Jobs::Periodic] Periodic job
        # @return [Jobs::PeriodicNonBlocking] Periodic non-blocking job
        def periodic(executor)
          if executor.topic.long_running_job?
            Jobs::PeriodicNonBlocking.new(executor)
          else
            Jobs::Periodic.new(executor)
          end
        end
      end
    end
  end
end
