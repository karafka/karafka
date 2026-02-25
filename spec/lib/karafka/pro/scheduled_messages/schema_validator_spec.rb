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
  let(:current_schema_version) { Karafka::Pro::ScheduledMessages::SCHEMA_VERSION }

  let(:expected_error) { Karafka::Pro::ScheduledMessages::Errors::IncompatibleSchemaError }

  describe ".call" do
    context "when the message schema version is compatible" do
      let(:message) do
        instance_double(
          Karafka::Messages::Message,
          headers: { "schedule_schema_version" => current_schema_version }
        )
      end

      it "does not raise an error" do
        expect { described_class.call(message) }.not_to raise_error
      end
    end

    context "when the message schema version is lower than current version" do
      let(:message) do
        instance_double(
          Karafka::Messages::Message,
          headers: { "schedule_schema_version" => "0.0.0" }
        )
      end

      it "does not raise an error" do
        expect { described_class.call(message) }.not_to raise_error
      end
    end

    context "when the message schema version is higher than current version" do
      let(:message) do
        instance_double(
          Karafka::Messages::Message,
          headers: { "schedule_schema_version" => "2.0.0" }
        )
      end

      it "raises an IncompatibleSchemaError" do
        expect { described_class.call(message) }.to raise_error(expected_error)
      end
    end
  end
end
