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
  subject(:check) { described_class.new.call(config) }

  let(:config) { { patterns: [] } }

  context "when config is valid" do
    it { expect(check).to be_success }
  end

  context "when patterns are not hashes" do
    before { config[:patterns] = [1, 2] }

    it { expect(check).not_to be_success }
  end

  context "when there is no patterns key" do
    before { config.delete(:patterns) }

    it { expect(check).not_to be_success }
  end

  context "when pattern is not valid" do
    before { config[:patterns] = [{}] }

    it { expect { check }.to raise_error(Karafka::Errors::InvalidConfigurationError) }
  end

  context "when pattern is valid" do
    before { config[:patterns] = [{ regexp: /.*/, name: "xda", regexp_string: "^test" }] }

    it { expect(check).to be_success }
  end

  context "when two patterns have different names but same regexp_string" do
    before do
      config[:patterns] = [
        { regexp: /.*/, name: "xda1", regexp_string: "^test" },
        { regexp: /.*/, name: "xda2", regexp_string: "^test" }
      ]
    end

    it { expect(check).not_to be_success }
  end
end
