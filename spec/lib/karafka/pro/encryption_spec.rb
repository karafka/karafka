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
  describe "envelope openssl constraint" do
    subject(:verification) { Karafka::Constraints.verify!(:config, config) }

    let(:mode) { :envelope }

    # Isolated real config (see the post_setup describe for the isolation rationale)
    let(:config) do
      config = Karafka::App.config.deep_dup
      config.compile
      config.encryption = Karafka::App.config.encryption.deep_dup
      config.encryption.compile
      config.encryption.active = true
      config.encryption.mode = mode
      config
    end

    context "when envelope mode runs on a recent enough openssl gem" do
      it "expect to pass" do
        expect { verification }.not_to raise_error
      end
    end

    context "when envelope mode runs on an openssl gem too old for the EVP PKey API" do
      before { stub_const("OpenSSL::VERSION", "2.2.1") }

      it "expect to raise the dependency constraints error" do
        expect { verification }.to raise_error(
          Karafka::Errors::DependencyConstraintsError,
          /requires the openssl gem >= 3\.0/
        )
      end
    end

    context "when direct mode runs on an openssl gem too old for the EVP PKey API" do
      let(:mode) { :direct }

      before { stub_const("OpenSSL::VERSION", "2.2.1") }

      it "expect not to raise as the EVP API is not used" do
        expect { verification }.not_to raise_error
      end
    end

    context "when encryption is not active on an old openssl gem" do
      before do
        config.encryption.active = false
        stub_const("OpenSSL::VERSION", "2.2.1")
      end

      it "expect not to raise" do
        expect { verification }.not_to raise_error
      end
    end
  end

  describe "#post_setup component wiring" do
    subject(:post_setup) { described_class.post_setup(config) }

    let(:mode) { :envelope }
    # A real, structurally isolated copy of the app config: assignments on it (including the
    # parser injection performed by post_setup) do not leak to the shared instance. Two shared
    # references need explicit replacement though: the encryption node (a leaf default shared
    # by reference across dups) and the producer service object.
    let(:config) do
      config = Karafka::App.config.deep_dup
      config.compile
      config.encryption = Karafka::App.config.encryption.deep_dup
      config.encryption.compile
      config.encryption.active = true
      config.encryption.mode = mode
      config.encryption.public_key = fixture_file("rsa/public_key_1.pem")
      # Fresh cipher local to this dup, so the warmup performed by post_setup does not touch
      # the shared default cipher instance
      config.encryption.cipher = Karafka::Pro::Encryption::Cipher.new
      config.producer = Struct.new(:middleware).new([])
      config
    end

    context "when encryption is active" do
      before { allow(config.encryption.cipher).to receive(:warmup).and_call_original }

      it "expect to inject both components and warm the cipher with the given config" do
        expect { post_setup }.not_to raise_error
        expect(config.producer.middleware.size).to eq(1)
        expect(config.encryption.cipher).to have_received(:warmup).with(config)
        expect(config.internal.messages.parser)
          .to be_a(Karafka::Pro::Encryption::Messages::Parser)
        # The shared config remains untouched by the injections and the local encryption
        # reconfiguration
        expect(Karafka::App.config.internal.messages.parser)
          .not_to be_a(Karafka::Pro::Encryption::Messages::Parser)
        expect(Karafka::App.config.encryption.active).to be(false)
      end
    end

    context "when envelope mode runs on an openssl gem too old for the EVP PKey API" do
      before { stub_const("OpenSSL::VERSION", "2.2.1") }

      it "expect to wire components regardless (the constraint is verified centrally)" do
        expect { post_setup }.not_to raise_error
        expect(config.producer.middleware.size).to eq(1)
      end
    end

    context "when encryption is not active" do
      before { config.encryption.active = false }

      it "expect not to inject anything" do
        expect { post_setup }.not_to raise_error
        expect(config.producer.middleware).to be_empty
      end
    end
  end
end
