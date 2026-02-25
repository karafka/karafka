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
      module Strategies
        # Namespace for ActiveJob related strategies
        module Aj
          # ActiveJob enabled
          # Filtering enabled
          # Manual Offset management enabled
          # Virtual partitions enabled
          module FtrMomVp
            include Strategies::Aj::FtrMom
            include Strategies::Aj::MomVp

            # Features for this strategy
            FEATURES = %i[
              active_job
              filtering
              manual_offset_management
              virtual_partitions
            ].freeze

            # AJ with VPs always has intermediate marking disabled, hence we need to do it post
            # execution always.
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  return if revoked?

                  mark_as_consumed(last_group_message)

                  handle_post_filtering
                else
                  retry_after_pause
                end
              end
            end
          end
        end
      end
    end
  end
end
