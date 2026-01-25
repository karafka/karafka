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
  subject(:check) { described_class.new.call(topic) }

  subject(:contract) { described_class.new }

  context "when patterns configuration is valid" do
    let(:topic) do
      {
        patterns: {
          active: true,
          type: :matcher
        }
      }
    end

    it { expect(check).to be_success }
  end

  context "when patterns active attribute is not valid" do
    let(:topic) do
      {
        patterns: {
          active: nil,
          type: :matcher
        }
      }
    end

    it { expect(check).not_to be_success }
  end

  context "when patterns type attribute is not valid" do
    let(:topic) do
      {
        patterns: {
          active: true,
          type: :invalid_type
        }
      }
    end

    it { expect(check).not_to be_success }
  end
end
