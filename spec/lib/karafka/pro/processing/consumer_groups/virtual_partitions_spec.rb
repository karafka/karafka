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
  describe ".pre_setup" do
    let(:config) do
      Class.new do
        extend Karafka::Core::Configurable

        configure
      end.config
    end

    before { described_class.pre_setup(config) }

    it { expect(config.consumer_groups.virtual_partitions.estimator.sample_size).to eq(10_000) }
  end

  describe ".post_setup" do
    let(:config) { Karafka::App.config }
    let(:estimator_config) { config.consumer_groups.virtual_partitions.estimator }
    let(:original_sample_size) { estimator_config.sample_size }

    it { expect { described_class.post_setup(config) }.not_to raise_error }

    context "when the estimator config is invalid" do
      before do
        original_sample_size
        estimator_config.sample_size = 0
      end

      after { estimator_config.sample_size = original_sample_size }

      it do
        expect { described_class.post_setup(config) }
          .to raise_error(Karafka::Errors::InvalidConfigurationError)
      end
    end
  end

  describe ".post_fork" do
    it { expect(described_class.post_fork(Karafka::App.config, nil)).to be(true) }
  end
end
