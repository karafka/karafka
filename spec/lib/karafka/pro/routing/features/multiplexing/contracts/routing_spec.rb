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
  subject(:validation) { described_class.new.validate!(builder) }

  let(:builder) { Karafka::App.config.internal.routing.builder.class.new }
  let(:validation_error) { Karafka::Errors::InvalidConfigurationError }

  after { builder.clear }

  context "when dynamic multiplexing is used with statistics disabled" do
    before do
      allow(Karafka::App.config.kafka).to receive(:[])
        .with(:"statistics.interval.ms")
        .and_return(0)

      sg = instance_double(
        Karafka::Routing::SubscriptionGroup,
        multiplexing?: true,
        multiplexing: instance_double(
          Karafka::Pro::Routing::Features::Multiplexing::Config,
          dynamic?: true
        )
      )

      allow(Karafka::App)
        .to receive(:subscription_groups)
        .and_return({ "group" => [sg] })
    end

    it { expect { validation }.to raise_error(validation_error) }
  end

  context "when dynamic multiplexing is used with statistics enabled" do
    before do
      allow(Karafka::App.config.kafka).to receive(:[])
        .with(:"statistics.interval.ms")
        .and_return(5_000)

      sg = instance_double(
        Karafka::Routing::SubscriptionGroup,
        multiplexing?: true,
        multiplexing: instance_double(
          Karafka::Pro::Routing::Features::Multiplexing::Config,
          dynamic?: true
        )
      )

      allow(Karafka::App)
        .to receive(:subscription_groups)
        .and_return({ "group" => [sg] })
    end

    it { expect { validation }.not_to raise_error }
  end

  context "when static multiplexing is used with statistics disabled" do
    before do
      allow(Karafka::App.config.kafka).to receive(:[])
        .with(:"statistics.interval.ms")
        .and_return(0)

      sg = instance_double(
        Karafka::Routing::SubscriptionGroup,
        multiplexing?: true,
        multiplexing: instance_double(
          Karafka::Pro::Routing::Features::Multiplexing::Config,
          dynamic?: false
        )
      )

      allow(Karafka::App)
        .to receive(:subscription_groups)
        .and_return({ "group" => [sg] })
    end

    it { expect { validation }.not_to raise_error }
  end

  context "when no multiplexing is used with statistics disabled" do
    before do
      allow(Karafka::App.config.kafka).to receive(:[])
        .with(:"statistics.interval.ms")
        .and_return(0)

      sg = instance_double(
        Karafka::Routing::SubscriptionGroup,
        multiplexing?: false
      )

      allow(Karafka::App)
        .to receive(:subscription_groups)
        .and_return({ "group" => [sg] })
    end

    it { expect { validation }.not_to raise_error }
  end
end
