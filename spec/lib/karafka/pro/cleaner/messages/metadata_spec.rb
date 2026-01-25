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
  subject(:metadata) { build(:messages_message).metadata }

  describe "#headers" do
    context "when metadata was not cleaned" do
      it { expect { metadata.headers }.not_to raise_error }
    end

    context "when metadata was cleaned" do
      let(:expected_error) { Karafka::Pro::Cleaner::Errors::MessageCleanedError }

      before { metadata.clean! }

      it { expect { metadata.headers }.to raise_error(expected_error) }
    end
  end

  describe "#key" do
    context "when metadata metadata was not cleaned" do
      it { expect { metadata.key }.not_to raise_error }
    end

    context "when metadata was cleaned" do
      let(:expected_error) { Karafka::Pro::Cleaner::Errors::MessageCleanedError }

      before { metadata.clean! }

      it { expect { metadata.key }.to raise_error(expected_error) }
    end
  end

  describe "#cleaned? and #clean!" do
    context "when metadata was not cleaned" do
      it { expect(metadata.cleaned?).to be(false) }
      it { expect(metadata.raw_key).not_to be(false) }
      it { expect(metadata.raw_headers).not_to be(false) }
    end

    context "when metadata was cleaned" do
      before { metadata.clean! }

      it { expect(metadata.cleaned?).to be(true) }
      it { expect(metadata.raw_key).to be(false) }
      it { expect(metadata.raw_headers).to be(false) }
    end

    context "when metadata was deserialized and cleaned" do
      before do
        metadata.key
        metadata.headers
        metadata.clean!
      end

      it { expect(metadata.cleaned?).to be(true) }
      it { expect(metadata.raw_key).to be(false) }
      it { expect(metadata.raw_headers).to be(false) }
    end
  end
end
