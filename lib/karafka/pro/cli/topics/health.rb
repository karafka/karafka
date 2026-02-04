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
    module Cli
      module Topics
        # Checks health of Kafka topics by analyzing replication and durability settings
        # Identifies topics with:
        # - No redundancy (RF=1)
        # - Zero fault tolerance (RF <= min.insync.replicas)
        # - Low durability (min.insync.replicas=1)
        class Health < Karafka::Cli::Topics::Base
          # Executes the health check across all topics in the cluster
          # @return [Boolean] true if issues were found, false if all topics are healthy
          def call
            issues = []

            supervised("Checking topics health") do
              existing_topics.each do |topic|
                topic_name = topic[:topic_name]

                # Skip internal Kafka topics
                next if topic_name.start_with?("__")

                # Get replication factor from first partition
                rf = topic[:partitions].first&.fetch(:replica_count) || 0

                # Fetch topic configuration
                configs = Admin::Configs.describe(
                  Admin::Configs::Resource.new(type: :topic, name: topic_name)
                ).first.configs

                # Extract min.insync.replicas setting
                min_isr = configs.find { |c| c.name == "min.insync.replicas" }&.value&.to_i || 1

                # Check for issues
                if rf == 1
                  issues << {
                    topic: topic_name,
                    rf: rf,
                    min_isr: min_isr,
                    severity: :critical,
                    message: "RF=#{rf} (no redundancy)"
                  }
                elsif rf <= min_isr
                  issues << {
                    topic: topic_name,
                    rf: rf,
                    min_isr: min_isr,
                    severity: :critical,
                    message: "RF=#{rf}, min.insync=#{min_isr} (zero fault tolerance)"
                  }
                elsif min_isr == 1
                  issues << {
                    topic: topic_name,
                    rf: rf,
                    min_isr: min_isr,
                    severity: :warning,
                    message: "RF=#{rf}, min.insync=#{min_isr} (low durability)"
                  }
                end
              end
            end

            # Display results
            puts

            if issues.any?
              puts "#{red("Issues found")}:"
              puts

              # Group by severity
              critical_issues = issues.select { |i| i[:severity] == :critical }
              warning_issues = issues.select { |i| i[:severity] == :warning }

              if critical_issues.any?
                puts "#{red("Critical")}:"
                critical_issues.each do |issue|
                  puts "  #{red("\u2022")} #{issue[:topic]}: #{issue[:message]}"
                end
                puts if warning_issues.any?
              end

              if warning_issues.any?
                puts "#{yellow("Warnings")}:"
                warning_issues.each do |issue|
                  puts "  #{yellow("\u2022")} #{issue[:topic]}: #{issue[:message]}"
                end
              end

              puts
              puts "#{grey("Recommendations")}:"
              puts "  #{grey("\u2022")} Ensure RF >= 3 for production topics"
              puts "  #{grey("\u2022")} Set min.insync.replicas to at least 2"
              puts "  #{grey("\u2022")} Maintain RF > min.insync.replicas for fault tolerance"
            else
              puts "#{green("\u2713")} All topics are healthy"
            end

            puts

            # Return true if issues found (for exit code handling)
            issues.any?
          end
        end
      end
    end
  end
end
