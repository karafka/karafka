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
  subject(:registry) { described_class.new }

  let(:lags) { Karafka::Pro::Actions::Lags }
  let(:replacement) { Class.new(lags) }
  let(:errors) { Karafka::Pro::Actions::Errors }

  it { expect(registry.to_a).to eq([]) }

  context "when adding a read action" do
    before { registry.add(lags) }

    it { expect(registry.fetch("lags")).to eq(lags) }
    it { expect(registry.fetch(:lags)).to eq(lags) }
  end

  context "when adding the same action twice" do
    before { 2.times { registry.add(lags) } }

    it { expect(registry.to_a).to eq([lags]) }
  end

  context "when replacing an action with its subclass" do
    before do
      registry.add(lags)
      registry.add(replacement)
    end

    it { expect(registry.fetch("lags")).to eq(replacement) }
  end

  context "when replacing an action with a class that does not inherit from it" do
    let(:other) { Class.new(Karafka::Pro::Actions::Read) { action_name "lags" } }

    before { registry.add(lags) }

    it { expect { registry.add(other) }.to raise_error(errors::InvalidActionError) }
  end

  context "when replacing a subclass with its parent" do
    before { registry.add(replacement) }

    it { expect { registry.add(lags) }.to raise_error(errors::InvalidActionError) }
  end

  context "when adding something that is not a read action" do
    it { expect { registry.add(Karafka::Pro::Actions::Base) }.to raise_error(errors::InvalidActionError) }
    it { expect { registry.add(Class.new) }.to raise_error(errors::InvalidActionError) }

    it "expect to reject a Base subclass that is not a read action" do
      write = Class.new(Karafka::Pro::Actions::Base) { action_name "write" }

      expect { registry.add(write) }.to raise_error(errors::InvalidActionError)
    end
  end

  context "when fetching an unknown action" do
    it { expect { registry.fetch("delete") }.to raise_error(errors::UnknownActionError, "delete") }
  end

  context "when cleared" do
    before do
      registry.add(lags)
      registry.clear
    end

    it { expect(registry.to_a).to eq([]) }
  end
end
