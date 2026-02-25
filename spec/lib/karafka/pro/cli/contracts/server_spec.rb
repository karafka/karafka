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
  subject(:contract) { described_class.new }

  let(:subscription_groups) { { 1 => 1 } }
  let(:config) do
    {
      include_consumer_groups: [],
      include_subscription_groups: [],
      include_topics: [],
      exclude_consumer_groups: [],
      exclude_subscription_groups: [],
      exclude_topics: []
    }
  end

  before { allow(Karafka::App).to receive(:subscription_groups).and_return(subscription_groups) }

  context "when config is valid" do
    it { expect(contract.call(config)).to be_success }
  end

  context "when we want to use consumer groups that are not defined" do
    before { config[:include_consumer_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when we want to exclude consumer groups that are not defined" do
    before { config[:exclude_consumer_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when we want to use topics that are not defined" do
    before { config[:include_topics] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }

    context "when we have pattern matching defined" do
      before do
        Karafka::App.consumer_groups.pattern(/test/) do
          consumer Class.new
        end
      end

      it { expect(contract.call(config)).to be_success }
    end
  end

  context "when we want to exclude topics that are not defined" do
    before { config[:exclude_topics] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }

    context "when we have pattern matching defined" do
      before do
        Karafka::App.consumer_groups.pattern(/test/) do
          consumer Class.new
        end
      end

      it { expect(contract.call(config)).to be_success }
    end
  end

  context "when we want to use subscription groups that are not defined" do
    before { config[:include_subscription_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when we want to exclude subscription groups that are not defined" do
    before { config[:exclude_subscription_groups] = [rand.to_s] }

    it { expect(contract.call(config)).not_to be_success }
  end

  context "when nothing to listen on" do
    let(:subscription_groups) { {} }

    it { expect(contract.call(config)).not_to be_success }
  end
end
