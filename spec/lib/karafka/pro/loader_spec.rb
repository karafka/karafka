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
  subject(:loader) { described_class }

  before do
    # We do not want to load extensions as they would leak into other specs
    allow(loader).to receive(:load_routing_extensions)
  end

  context "when we are loading active_job pro compoments" do
    let(:aj_defaults) { Karafka::App.config.internal.active_job.deep_dup.tap(&:configure) }
    let(:aj_config) { Karafka::App.config.internal.active_job }

    before { aj_defaults }

    after do
      aj_defaults.to_h.each do |key, value|
        Karafka::App.config.internal.active_job.public_send("#{key}=", value)
      end
    end

    context "when we run pre_setup_all loader" do
      before do
        allow(Karafka::Pro::Routing::Features::VirtualPartitions).to receive(:activate)
        allow(Karafka::Pro::Routing::Features::LongRunningJob).to receive(:activate)

        loader.pre_setup_all(Karafka::App.config)
      end

      it "expect to change active job components into pro" do
        expect(aj_config.dispatcher).to be_a(Karafka::Pro::ActiveJob::Dispatcher)
        expect(aj_config.job_options_contract).to be_a(Karafka::Pro::ActiveJob::JobOptionsContract)
      end
    end
  end
end
