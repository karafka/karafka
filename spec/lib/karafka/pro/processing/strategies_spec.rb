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

RSpec.describe_current do
  let(:message) { build(:messages_message) }
  let(:coordinator) { build(:processing_coordinator_pro, seek_offset: 0, topic: topic) }
  let(:topic) { build(:routing_topic) }
  let(:client) { instance_double(Karafka::Connection::Client, pause: true) }
  let(:messages_batch) do
    Karafka::Messages::Builders::Messages.call([message], topic, 0, Time.now)
  end
  let(:consumer) do
    consumer = Karafka::BaseConsumer.new
    consumer.client = client
    consumer.coordinator = coordinator
    consumer.messages = messages_batch
    consumer
  end

  strategies = Karafka::Pro::Processing::StrategySelector.new.strategies

  strategies
    .select { |strategy| strategy::FEATURES.include?(:virtual_partitions) }
    .each do |strategy|
      context "when having VP strategy: #{strategy}" do
        let(:topic) do
          topic = build(:routing_topic)
          topic.virtual_partitions(partitioner: true)
          topic
        end

        it "expect all of them to have #collapsed? method" do
          expect(strategy.method_defined?(:collapsed?)).to be(true)
        end

        it "expect all of them to have #failing? method" do
          expect(strategy.method_defined?(:failing?)).to be(true)
        end

        context "when using VPs and VPs virtual marking" do
          before { consumer.singleton_class.include(strategy) }

          it "expect #handle_before_schedule_consume to always register virtual offsets groups" do
            consumer.send(:handle_before_schedule_consume)

            expect(coordinator.virtual_offset_manager.groups).not_to be_empty
          end
        end
      end
    end

  strategies
    .select { |strategy| strategy::FEATURES.include?(:virtual_partitions) }
    .select { |strategy| strategy::FEATURES.include?(:dead_letter_queue) }
    .each do |strategy|
      context "when having DLQ and VP strategy: #{strategy}" do
        it "expect to include the Dlq::Vp strategy in the chain" do
          expect(strategy.ancestors).to include(Karafka::Pro::Processing::Strategies::Dlq::Vp)
        end
      end
    end

  strategies
    .reject { |strategy| strategy::FEATURES.include?(:virtual_partitions) }
    .each do |strategy|
      context "when having non-VP strategy: #{strategy}" do
        before { consumer.singleton_class.include(strategy) }

        it "expect not to have any VP related components" do
          strategy.ancestors.each do |ancestor|
            next if ancestor.to_s.end_with?("::Base")

            expect(ancestor::FEATURES).not_to include(:virtual_partitions)
            expect(ancestor.to_s).not_to include("::Vp")
          end
        end

        it "expect #handle_before_schedule_consume to never register virtual offsets groups" do
          consumer.send(:handle_before_schedule_consume)

          expect(coordinator.virtual_offset_manager).to be_nil
        end

        it "expect #handle_before_schedule_consume to not fail without virtual_offset_manager" do
          expect { consumer.send(:handle_before_schedule_consume) }.not_to raise_error
        end
      end
    end

  strategies
    .select { |strategy| strategy::FEATURES.include?(:long_running_job) }
    .each do |strategy|
      context "when having an LRJ strategy: #{strategy}" do
        let(:topic) do
          topic = build(:routing_topic)
          topic.virtual_partitions(partitioner: true) if strategy.to_s.include?("Vp")
          topic
        end

        before do
          consumer.singleton_class.include(strategy)
          allow(client).to receive(:pause)
        end

        it "expect #handle_before_schedule_consume to invoke pause on a client" do
          consumer.send(:handle_before_schedule_consume)

          expect(client).to have_received(:pause)
        end
      end
    end

  strategies
    .reject { |strategy| strategy::FEATURES.include?(:long_running_job) }
    .each do |strategy|
      context "when having a non LRJ strategy: #{strategy}" do
        let(:topic) do
          topic = build(:routing_topic)
          topic.virtual_partitions(partitioner: true) if strategy.to_s.include?("Vp")
          topic
        end

        before do
          consumer.singleton_class.include(strategy)
          allow(client).to receive(:pause)
        end

        it "expect #handle_before_schedule_consume to never invoke pause on a client" do
          consumer.send(:handle_before_schedule_consume)

          expect(client).not_to have_received(:pause)
        end
      end
    end
end
