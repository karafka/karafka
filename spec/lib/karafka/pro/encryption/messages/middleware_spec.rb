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
  subject(:middleware) { described_class.new.call(message) }

  before do
    allow(Karafka::App.config.encryption).to receive_messages(
      public_key: fixture_file("rsa/public_key_1.pem"),
      private_keys: { "1" => fixture_file("rsa/private_key_1.pem") }
    )
  end

  let(:message) do
    {
      headers: {},
      payload: "test message"
    }
  end

  it "expect to encrypt the payload" do
    encrypted = middleware[:payload]

    expect(Karafka::App.config.encryption.cipher.decrypt("1", encrypted)).to eq("test message")
  end

  it "expect to add encryption version to headers" do
    expect { middleware }
      .to change { message[:headers] }
      .from({})
      .to("encryption" => "1")
  end

  context "when custom fingerprinter is defined" do
    let(:expected) do
      <<~DIGEST.delete("\n")
        92bf445810db8cbd9802
        cd585fb76e08801b8202
        e923ee842be8179a97ee
        c4078d4cf45a3b3d5201
        1d0ca7bbfd9c2e2b
      DIGEST
    end

    before do
      allow(Karafka::App.config.encryption)
        .to receive(:fingerprinter)
        .and_return(Digest::SHA384)
    end

    it "expect to use it and create fingerprint header" do
      expect { middleware }
        .to change { message[:headers] }
        .from({})
        .to("encryption" => "1", "encryption_fingerprint" => expected)
    end
  end
end
