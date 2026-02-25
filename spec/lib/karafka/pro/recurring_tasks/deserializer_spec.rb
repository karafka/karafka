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
  subject(:parsing) { described_class.new.call(message) }

  let(:message) { instance_double(Karafka::Messages::Message) }
  let(:raw_payload) { '{"key":"value"}' }
  let(:headers) { {} }

  before do
    allow(message).to receive_messages(
      raw_payload: raw_payload,
      headers: headers
    )
  end

  let(:raw_payload) { Zlib::Deflate.deflate('{"key":"value"}') }

  context "when JSON is parsed successfully" do
    it "returns a hash" do
      expect(parsing).to be_a(Hash)
    end

    it "returns a hash with symbolized keys" do
      expect(parsing.keys.all?(Symbol)).to be(true)
    end

    it "returns a hash with expected values" do
      expect(parsing).to eq({ key: "value" })
    end
  end

  context "when JSON parsing fails" do
    let(:raw_payload) { Zlib::Deflate.deflate("invalid json") }

    it "raises a JSON::ParserError" do
      expect { parsing }.to raise_error(JSON::ParserError)
    end
  end

  context "when data is not compressed" do
    let(:raw_payload) { "not compressed" }

    it "raises a Zlib::DataError" do
      expect { parsing }.to raise_error(Zlib::DataError)
    end
  end
end
