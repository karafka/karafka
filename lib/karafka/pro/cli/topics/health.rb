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
            issues_found = false

            supervised("Checking topics health") do
              topics = existing_topics
              puts "Found #{topics.count} topics to check..."
              puts

              topics.each do |topic|
                # Skip internal Kafka topics
                next if topic[:topic_name].start_with?("__")

                issue = analyze_topic(topic)

                if issue
                  display_issue(issue)
                  issues_found = true
                else
                  puts "#{green("✓")} #{topic[:topic_name]}"
                end
              end
            end

            puts
            display_summary(issues_found)
            puts

            issues_found
          end

          private

          # Analyzes a single topic for replication and durability issues
          # @param topic [Hash] topic metadata from cluster info
          # @return [Hash, nil] issue hash if problems found, nil if healthy
          def analyze_topic(topic)
            topic_name = topic[:topic_name]
            rf = topic[:partitions].first&.fetch(:replica_count) || 0
            min_isr = fetch_min_insync_replicas(topic_name)

            check_replication_issue(topic_name, rf, min_isr)
          end

          # Fetches min.insync.replicas configuration for a topic
          # @param topic_name [String] name of the topic
          # @return [Integer] min.insync.replicas value
          def fetch_min_insync_replicas(topic_name)
            configs = Admin::Configs.describe(
              Admin::Configs::Resource.new(type: :topic, name: topic_name)
            ).first.configs

            configs.find { |c| c.name == "min.insync.replicas" }.value.to_i
          end

          # Checks for replication and durability issues
          # @param topic_name [String] name of the topic
          # @param rf [Integer] replication factor
          # @param min_isr [Integer] min.insync.replicas setting
          # @return [Hash, nil] issue hash if problems found, nil if healthy
          def check_replication_issue(topic_name, rf, min_isr)
            return build_issue(topic_name, rf, min_isr, :critical, "RF=#{rf} (no redundancy)") if rf == 1

            if rf <= min_isr
              return build_issue(
                topic_name,
                rf,
                min_isr,
                :critical,
                "RF=#{rf}, min.insync=#{min_isr} (zero fault tolerance)"
              )
            end

            if min_isr == 1
              return build_issue(
                topic_name,
                rf,
                min_isr,
                :warning,
                "RF=#{rf}, min.insync=#{min_isr} (low durability)"
              )
            end

            nil
          end

          # Builds an issue hash with consistent structure
          # @param topic [String] topic name
          # @param rf [Integer] replication factor
          # @param min_isr [Integer] min.insync.replicas
          # @param severity [Symbol] :critical or :warning
          # @param message [String] human-readable issue description
          # @return [Hash] issue details
          def build_issue(topic, rf, min_isr, severity, message)
            {
              topic: topic,
              rf: rf,
              min_isr: min_isr,
              severity: severity,
              message: message
            }
          end

          # Displays a single issue immediately as it's found
          # @param issue [Hash] issue details
          def display_issue(issue)
            color_method = (issue[:severity] == :critical) ? :red : :yellow
            symbol = (issue[:severity] == :critical) ? "\u2717" : "\u26A0"
            puts "#{send(color_method, symbol)} #{issue[:topic]}: #{issue[:message]}"
          end

          # Displays final summary and recommendations
          # @param issues_found [Boolean] whether any issues were found
          def display_summary(issues_found)
            if issues_found
              puts
              puts "#{grey("Recommendations")}:"
              puts "  #{grey("\u2022")} Ensure RF >= 3 for production topics"
              puts "  #{grey("\u2022")} Set min.insync.replicas to at least 2"
              puts "  #{grey("\u2022")} Maintain RF > min.insync.replicas for fault tolerance"
            else
              puts "#{green("\u2713")} All topics are healthy"
            end
          end
        end
      end
    end
  end
end
