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
  subject(:contract) { described_class.new }

  let(:config) do
    {
      recurring_tasks: {
        consumer_class: consumer_class,
        deserializer: Class.new,
        group_id: "valid_group_id",
        logging: true,
        interval: 5_000,
        topics: {
          schedules: {
            name: "valid_schedule_topic"
          },
          logs: {
            name: "valid_log_topic"
          }
        }
      }
    }
  end

  let(:consumer_class) { Class.new(Karafka::BaseConsumer) }
  let(:recurring_tasks) { config[:recurring_tasks] }

  context "when config is valid" do
    it { expect(contract.call(config)).to be_success }
  end

  context "when consumer_class is not a subclass of Karafka::BaseConsumer" do
    before { recurring_tasks[:consumer_class] = Class.new }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when group_id does not match the required format" do
    before { recurring_tasks[:group_id] = "invalid group id" }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when interval is less than 1000 milliseconds" do
    before { recurring_tasks[:interval] = 999 }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when interval is not an integer" do
    before { recurring_tasks[:interval] = "not an integer" }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when deserializer is nil" do
    before { recurring_tasks[:deserializer] = nil }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when logging is nil" do
    before { recurring_tasks[:logging] = nil }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when schedules topic does not match the required format" do
    before { recurring_tasks[:topics][:schedules][:name] = "invalid schedule topic" }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when logs topic does not match the required format" do
    before { recurring_tasks[:topics][:logs][:name] = "invalid log topic" }

    it { expect(contract.call(config)).not_to be_success }
  end
end
