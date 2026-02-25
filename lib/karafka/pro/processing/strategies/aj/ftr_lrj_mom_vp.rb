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
        module Aj
          # ActiveJob enabled
          # Filtering enabled
          # Long-Running Job enabled
          # Manual offset management enabled
          # Virtual Partitions enabled
          module FtrLrjMomVp
            include Strategies::Vp::Default
            include Strategies::Lrj::FtrMom

            # Features for this strategy
            FEATURES = %i[
              active_job
              filtering
              long_running_job
              manual_offset_management
              virtual_partitions
            ].freeze

            # AJ MOM VP does not do intermediate marking, hence we need to make sure we mark as
            # consumed here.
            def handle_after_consume
              coordinator.on_finished do |last_group_message|
                if coordinator.success?
                  coordinator.pause_tracker.reset

                  mark_as_consumed(last_group_message) unless revoked?

                  if coordinator.filtered? && !revoked?
                    handle_post_filtering
                  elsif !revoked?
                    # no need to check for manual seek because AJ consumer is internal and
                    # fully controlled by us
                    seek(seek_offset, false, reset_offset: false)
                    resume
                  else
                    resume
                  end
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
