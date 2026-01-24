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
    module Routing
      module Features
        class ActiveJob < Base
          # Pro ActiveJob builder expansions
          module Builder
            # This method simplifies routes definition for ActiveJob patterns / queues by
            # auto-injecting the consumer class and other things needed
            #
            # @param regexp_or_name [String, Symbol, Regexp] pattern name or regexp to use
            #   auto-generated regexp names
            # @param regexp [Regexp, nil] activejob regexp pattern or nil when regexp is provided
            #   as the first argument
            # @param block [Proc] block that we can use for some extra configuration
            def active_job_pattern(regexp_or_name, regexp = nil, &block)
              pattern(regexp_or_name, regexp) do
                consumer App.config.internal.active_job.consumer_class
                active_job true
                manual_offset_management true

                next unless block

                instance_eval(&block)
              end
            end
          end
        end
      end
    end
  end
end
