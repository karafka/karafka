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

  context "with valid configurations" do
    let(:config) do
      {
        direct_assignments: {
          active: true,
          partitions: { 1 => true, 2 => true }
        },
        swarm: {
          active: false
        },
        patterns: {
          active: false
        }
      }
    end

    it "is expected to be successful" do
      expect(validation_result).to be_success
    end
  end

  context "when active is not a boolean" do
    let(:config) do
      {
        direct_assignments: {
          active: "true", # Invalid type
          partitions: { 1 => true }
        },
        swarm: {
          active: false
        },
        patterns: {
          active: false
        }
      }
    end

    it "is expected to fail" do
      expect(validation_result).not_to be_success
    end
  end

  context "when partitions are not exclusively integers mapping to true" do
    let(:config) do
      {
        direct_assignments: {
          active: true,
          partitions: { "1" => true, 2 => false } # Invalid key type and value
        },
        swarm: {
          active: false
        },
        patterns: {
          active: false
        }
      }
    end

    it "is expected to fail" do
      expect(validation_result).not_to be_success
    end
  end

  context "when partitions are set to true" do
    let(:config) do
      {
        direct_assignments: {
          active: true,
          partitions: true
        },
        swarm: {
          active: false
        },
        patterns: {
          active: false
        }
      }
    end

    it "is expected to be successful" do
      expect(validation_result).to be_success
    end
  end

  context "when partitions is an empty hash" do
    let(:config) do
      {
        direct_assignments: {
          active: true,
          partitions: {} # Empty hash is not valid
        },
        swarm: {
          active: false
        },
        patterns: {
          active: false
        }
      }
    end

    it "is expected to fail" do
      expect(validation_result).not_to be_success
    end
  end

  context "when we assigned more partitions than allocated in swarm" do
    let(:config) do
      {
        direct_assignments: {
          active: true,
          partitions: { 0 => true, 1 => true, 2 => true, 3 => true }
        },
        swarm: {
          active: true,
          nodes: { 0 => [0], 1 => [1] }
        },
        patterns: {
          active: false
        }
      }
    end

    it { expect(validation_result).not_to be_success }
  end

  context "when we allocated more partitions than assigned" do
    let(:config) do
      {
        direct_assignments: {
          active: true,
          partitions: { 0 => true, 1 => true, 2 => true }
        },
        swarm: {
          active: true,
          nodes: { 0 => [0], 1 => [1, 2, 3] }
        },
        patterns: {
          active: false
        }
      }
    end

    it { expect(validation_result).not_to be_success }
  end

  context "when direct assignments are used with patterns" do
    let(:config) do
      {
        direct_assignments: {
          active: true,
          partitions: true
        },
        swarm: {
          active: false
        },
        patterns: {
          active: true
        }
      }
    end

    it "is expected to fail" do
      expect(validation_result).not_to be_success
    end
  end
end
