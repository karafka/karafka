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
            issues = supervised("Checking topics health") { collect_issues }
            display_results(issues)
            issues.any?
          end

          private

          # Collects health issues from all non-internal topics
          # @return [Array<Hash>] array of issue hashes with topic details
          def collect_issues
            existing_topics.each_with_object([]) do |topic, issues|
              # Skip internal Kafka topics
              next if topic[:topic_name].start_with?("__")

              issue = analyze_topic(topic)
              issues << issue if issue
            end
          end

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
          # @return [Integer] min.insync.replicas value, defaults to 1
          def fetch_min_insync_replicas(topic_name)
            configs = Admin::Configs.describe(
              Admin::Configs::Resource.new(type: :topic, name: topic_name)
            ).first.configs

            configs.find { |c| c.name == "min.insync.replicas" }&.value&.to_i || 1
          end

          # Checks for replication and durability issues
          # @param topic_name [String] name of the topic
          # @param rf [Integer] replication factor
          # @param min_isr [Integer] min.insync.replicas setting
          # @return [Hash, nil] issue hash if problems found, nil if healthy
          def check_replication_issue(topic_name, rf, min_isr)
            if rf == 1
              build_issue(topic_name, rf, min_isr, :critical, "RF=#{rf} (no redundancy)")
            elsif rf <= min_isr
              build_issue(
                topic_name,
                rf,
                min_isr,
                :critical,
                "RF=#{rf}, min.insync=#{min_isr} (zero fault tolerance)"
              )
            elsif min_isr == 1
              build_issue(
                topic_name,
                rf,
                min_isr,
                :warning,
                "RF=#{rf}, min.insync=#{min_isr} (low durability)"
              )
            end
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

          # Displays health check results with color-coded output
          # @param issues [Array<Hash>] collected issues
          def display_results(issues)
            puts

            if issues.any?
              display_issues(issues)
            else
              puts "#{green("\u2713")} All topics are healthy"
            end

            puts
          end

          # Displays issues grouped by severity
          # @param issues [Array<Hash>] collected issues
          def display_issues(issues)
            puts "#{red("Issues found")}:"
            puts

            critical_issues = issues.select { |i| i[:severity] == :critical }
            warning_issues = issues.select { |i| i[:severity] == :warning }

            display_critical_issues(critical_issues) if critical_issues.any?
            puts if critical_issues.any? && warning_issues.any?
            display_warning_issues(warning_issues) if warning_issues.any?

            puts
            display_recommendations
          end

          # Displays critical issues
          # @param issues [Array<Hash>] critical issues
          def display_critical_issues(issues)
            puts "#{red("Critical")}:"
            issues.each do |issue|
              puts "  #{red("\u2022")} #{issue[:topic]}: #{issue[:message]}"
            end
          end

          # Displays warning issues
          # @param issues [Array<Hash>] warning issues
          def display_warning_issues(issues)
            puts "#{yellow("Warnings")}:"
            issues.each do |issue|
              puts "  #{yellow("\u2022")} #{issue[:topic]}: #{issue[:message]}"
            end
          end

          # Displays recommendations for addressing issues
          def display_recommendations
            puts "#{grey("Recommendations")}:"
            puts "  #{grey("\u2022")} Ensure RF >= 3 for production topics"
            puts "  #{grey("\u2022")} Set min.insync.replicas to at least 2"
            puts "  #{grey("\u2022")} Maintain RF > min.insync.replicas for fault tolerance"
          end
        end
      end
    end
  end
end
