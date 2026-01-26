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
  subject(:base_command) { described_class.new(options) }

  let(:options) { {} }

  describe "#initialize" do
    context "when options are provided" do
      let(:options) { { groups: ["group1"], force: true } }

      it "creates an instance with the provided options" do
        expect(base_command).to be_an_instance_of(described_class)
      end
    end

    context "when no options are provided" do
      let(:options) { {} }

      it "creates an instance with empty options" do
        expect(base_command).to be_an_instance_of(described_class)
      end
    end
  end
end
