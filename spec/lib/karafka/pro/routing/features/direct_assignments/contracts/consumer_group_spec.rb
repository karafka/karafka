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
  subject(:validation_result) { described_class.new.call(config) }

  context "with all topics using direct assignments" do
    let(:config) do
      {
        topics: [
          { direct_assignments: { active: true } },
          { direct_assignments: { active: true } }
        ]
      }
    end

    it "is expected to be successful" do
      expect(validation_result).to be_success
    end
  end

  context "with no topics using direct assignments" do
    let(:config) do
      {
        topics: [
          { direct_assignments: { active: false } },
          { direct_assignments: { active: false } }
        ]
      }
    end

    it "is expected to be successful" do
      expect(validation_result).to be_success
    end
  end

  context "with a mix of topics using and not using direct assignments" do
    let(:config) do
      {
        topics: [
          { direct_assignments: { active: true } },
          { direct_assignments: { active: false } }
        ]
      }
    end

    it "is expected to fail" do
      expect(validation_result).not_to be_success
    end
  end

  context "with a single topic" do
    context "when using direct assignments" do
      let(:config) do
        {
          topics: [
            { direct_assignments: { active: true } }
          ]
        }
      end

      it "is expected to be successful" do
        expect(validation_result).to be_success
      end
    end

    context "when not using direct assignments" do
      let(:config) do
        {
          topics: [
            { direct_assignments: { active: false } }
          ]
        }
      end

      it "is expected to be successful" do
        expect(validation_result).to be_success
      end
    end
  end
end
