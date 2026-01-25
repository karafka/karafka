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
  subject(:matcher) { described_class.new }

  let(:task) { Karafka::Pro::RecurringTasks::Task.new(id: "task 1", cron: "* * * * *") }
  let(:schema_version) { "1.0" }

  let(:payload) do
    {
      type: "command",
      task: { id: task_id },
      schema_version: schema_version
    }
  end

  before do
    schedule = Karafka::Pro::RecurringTasks::Schedule.new(version: "1.0.1")
    schedule << task

    allow(Karafka::Pro::RecurringTasks)
      .to receive(:schedule)
      .and_return(schedule)
  end

  describe "#matches?" do
    context "when payload type is not command" do
      let(:payload) { super().merge(type: "log") }
      let(:task_id) { task.id }

      it "returns false" do
        expect(matcher.matches?(task, payload)).to be(false)
      end
    end

    context "when task id in payload does not match task id" do
      let(:task_id) { "different_task_id" }

      it "returns false" do
        expect(matcher.matches?(task, payload)).to be(false)
      end
    end

    context "when task id in payload is wildcard (*)" do
      let(:task_id) { "*" }

      it "returns true" do
        expect(matcher.matches?(task, payload)).to be(true)
      end
    end

    context "when schema version in payload does not match" do
      let(:task_id) { task.id }
      let(:schema_version) { "0.9" }

      it "returns false" do
        expect(matcher.matches?(task, payload)).to be(false)
      end
    end

    context "when all conditions match" do
      let(:task_id) { task.id }

      it "returns true" do
        expect(matcher.matches?(task, payload)).to be(true)
      end
    end
  end
end
