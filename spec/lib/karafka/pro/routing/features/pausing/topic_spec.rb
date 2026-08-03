# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

RSpec.describe_current do
  subject(:topic) { build(:routing_topic) }

  describe "#pause" do
    context "when pause has not been called" do
      it "returns a Config object with default values" do
        expect(topic.pause).to be_a(Karafka::Pro::Routing::Features::Pausing::Config)
        expect(topic.pause.active?).to be(false)
        expect(topic.pause.timeout).to eq(1)
        expect(topic.pause.max_timeout).to eq(1)
        expect(topic.pause.with_exponential_backoff).to be(false)
        expect(topic.pause.with_exponential_backoff?).to be(false)
      end
    end

    context "when called without arguments repeatedly" do
      it "returns the same memoized config" do
        expect(topic.pause).to equal(topic.pause)
      end
    end

    context "when setting only timeout with rest of defaults" do
      before { topic.pause(timeout: 100) }

      it "expect to change only timeout in config" do
        expect(topic.pause.timeout).to eq(100)
        expect(topic.pause.max_timeout).to eq(1)
        expect(topic.pause.with_exponential_backoff).to be(false)
        expect(topic.pause.active?).to be(true)
      end
    end

    context "when setting only max_timeout with rest of defaults" do
      before { topic.pause(max_timeout: 100) }

      it "expect to change only max_timeout in config" do
        expect(topic.pause.timeout).to eq(1)
        expect(topic.pause.max_timeout).to eq(100)
        expect(topic.pause.with_exponential_backoff).to be(false)
        expect(topic.pause.active?).to be(true)
      end
    end

    context "when setting only with_exponential_backoff with rest of defaults" do
      before { topic.pause(with_exponential_backoff: true) }

      it "expect to change only with_exponential_backoff in config" do
        expect(topic.pause.timeout).to eq(1)
        expect(topic.pause.max_timeout).to eq(1)
        expect(topic.pause.with_exponential_backoff).to be(true)
        expect(topic.pause.with_exponential_backoff?).to be(true)
        expect(topic.pause.active?).to be(true)
      end
    end

    context "when we change all" do
      before do
        topic.pause(
          timeout: 100,
          max_timeout: 150,
          with_exponential_backoff: true
        )
      end

      it "expect to change all in config" do
        expect(topic.pause.timeout).to eq(100)
        expect(topic.pause.max_timeout).to eq(150)
        expect(topic.pause.with_exponential_backoff).to be(true)
        expect(topic.pause.active?).to be(true)
      end
    end
  end

  describe "#pause?" do
    context "when pause has not been called" do
      it { expect(topic.pause?).to be(false) }
    end

    context "when pause has been called" do
      before { topic.pause(timeout: 100) }

      it { expect(topic.pause?).to be(true) }
    end
  end

  describe "#to_h" do
    it { expect(topic.to_h.key?(:pause)).to be(true) }

    context "when pause is configured" do
      before { topic.pause(timeout: 100, max_timeout: 200, with_exponential_backoff: true) }

      it "includes pause config hash" do
        pause_hash = topic.to_h[:pause]
        expect(pause_hash[:active]).to be(true)
        expect(pause_hash[:timeout]).to eq(100)
        expect(pause_hash[:max_timeout]).to eq(200)
        expect(pause_hash[:with_exponential_backoff]).to be(true)
      end
    end
  end
end
