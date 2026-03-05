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

# rubocop:disable RSpec/SpecFilePathFormat
RSpec.describe Karafka::Cli::Info, type: :pro do
  subject(:info_cli) { described_class.new }

  before do
    allow(Karafka.logger).to receive(:info)
    allow(info_cli).to receive(:options).and_return(extended: true)
  end

  describe "#call with --extended and pro features" do
    context "when topic has virtual_partitions" do
      before do
        Karafka::App.consumer_groups.draw do
          topic :vp_topic do
            consumer Class.new(Karafka::BaseConsumer)
            virtual_partitions(partitioner: ->(msg) { msg.raw_payload })
          end
        end
      end

      it "expect to print virtual_partitions feature" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/virtual_partitions:/)
      end
    end

    context "when topic has long_running_job" do
      before do
        Karafka::App.consumer_groups.draw do
          topic :lrj_topic do
            consumer Class.new(Karafka::BaseConsumer)
            long_running_job(true)
          end
        end
      end

      it "expect to print long_running_job feature" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/long_running_job:/)
      end
    end

    context "when topic has throttling" do
      before do
        Karafka::App.consumer_groups.draw do
          topic :throttled_topic do
            consumer Class.new(Karafka::BaseConsumer)
            throttling(limit: 10, interval: 1_000)
          end
        end
      end

      it "expect to print throttling feature" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/throttling:/)
      end
    end

    context "when topic has expiring" do
      before do
        Karafka::App.consumer_groups.draw do
          topic :expiring_topic do
            consumer Class.new(Karafka::BaseConsumer)
            expiring(30_000)
          end
        end
      end

      it "expect to print expiring feature" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/expiring:/)
      end
    end

    context "when topic has delaying" do
      before do
        Karafka::App.consumer_groups.draw do
          topic :delayed_topic do
            consumer Class.new(Karafka::BaseConsumer)
            delaying(10_000)
          end
        end
      end

      it "expect to print delaying feature" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/delaying:/)
      end
    end

    context "when topic has multiple pro features" do
      before do
        Karafka::App.consumer_groups.draw do
          topic :multi_feature_topic do
            consumer Class.new(Karafka::BaseConsumer)
            virtual_partitions(partitioner: ->(msg) { msg.raw_payload })
            long_running_job(true)
            dead_letter_queue(topic: "dlq_target", max_retries: 3)
          end
        end
      end

      it "expect to print all enabled features" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/virtual_partitions:/)
        expect(Karafka.logger).to have_received(:info).with(/long_running_job:/)
        expect(Karafka.logger).to have_received(:info).with(/dead_letter_queue:/)
      end
    end

    context "when topic has dead_letter_queue with pro features" do
      before do
        Karafka::App.consumer_groups.draw do
          topic :dlq_pro_topic do
            consumer Class.new(Karafka::BaseConsumer)
            dead_letter_queue(topic: "dlq_target", max_retries: 5)
          end
        end
      end

      it "expect to print dead_letter_queue feature details" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/dead_letter_queue:/)
        expect(Karafka.logger).to have_received(:info).with(/topic="dlq_target"/)
        expect(Karafka.logger).to have_received(:info).with(/max_retries=5/)
      end
    end

    context "when subscription group has multiplexing" do
      before do
        Karafka::App.consumer_groups.draw do
          consumer_group :mx_group do
            subscription_group :mx_sg do
              multiplexing(max: 3, min: 1)

              topic :mx_topic do
                consumer Class.new(Karafka::BaseConsumer)
              end
            end
          end
        end
      end

      it "expect to print multiplexing info" do
        info_cli.call
        expect(Karafka.logger).to have_received(:info).with(/multiplexing: min=1, max=3/)
      end
    end

    context "when subscription group does not have multiplexing" do
      before do
        Karafka::App.consumer_groups.draw do
          consumer_group :no_mx_group do
            topic :no_mx_topic do
              consumer Class.new(Karafka::BaseConsumer)
            end
          end
        end
      end

      it "expect not to print multiplexing info" do
        info_cli.call
        expect(Karafka.logger).not_to have_received(:info).with(/multiplexing:/)
      end
    end
  end
end
# rubocop:enable RSpec/SpecFilePathFormat
