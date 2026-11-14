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
  subject(:builder) { described_class.new(settings: settings, details: details) }

  let(:settings) { { concurrency: 4, distribution: :consistent } }
  let(:details) { false }
  let(:topic_name) { "orders" }
  let(:partitions_batches) { { 0 => [batch(active_vps: 4)] } }
  let(:result) { builder.call(topic_name, partitions_batches) }

  def batch(
    active_vps:,
    messages: 8,
    utilization: 100.0,
    load_imbalance: 0.0,
    parallelization: 100.0,
    collapsed: false
  )
    {
      messages: messages,
      collapsed: collapsed,
      unique_keys: active_vps,
      null_keys: 0,
      active_vps: active_vps,
      group_sizes: Array.new(active_vps) { messages / active_vps },
      utilization: utilization,
      load_imbalance: load_imbalance,
      parallelization: parallelization,
      speedup: active_vps.to_f
    }
  end

  it { expect(result.keys).to eq(%i[format_version topic_name settings partitions summary]) }
  it { expect(result[:format_version]).to eq(Karafka::Pro::Processing::ConsumerGroups::VirtualPartitions::Estimator::FORMAT_VERSION) }
  it { expect(result[:settings]).to eq(settings) }
  it { expect(result[:summary]).not_to have_key(:batches_details) }

  it "is deeply frozen" do
    expect(result).to be_frozen
    expect(result[:settings]).to be_frozen
    expect(result[:partitions][0]).to be_frozen
    expect(result[:partitions][0][:active_vps]).to be_frozen
  end

  it "does not freeze the given topic name and settings" do
    topic_name = +"orders"

    builder.call(topic_name, partitions_batches)

    expect(topic_name).not_to be_frozen
    expect(settings).not_to be_frozen
  end

  context "when partitions are not in order" do
    let(:partitions_batches) { { 10 => [], 2 => [batch(active_vps: 1)], 0 => [] } }

    it { expect(result[:partitions].keys).to eq([0, 2, 10]) }
  end

  context "with batches of many partitions" do
    let(:partitions_batches) do
      {
        0 => [batch(active_vps: 4), batch(active_vps: 1, messages: 2)],
        1 => [batch(active_vps: 2, messages: 3)]
      }
    end

    it "aggregates the stats per partition and for all of them" do
      expect(result[:partitions][0]).to include(messages: 10, batches: 2, avg_active_vps: 2.5)
      expect(result[:partitions][1]).to include(messages: 3, batches: 1, avg_active_vps: 2.0)
      expect(result[:summary]).to include(
        messages: 13,
        batches: 3,
        avg_active_vps: 2.3,
        active_vps: { min: 1, median: 2, max: 4 },
        poor_batches: 1,
        single_vp_batches: 1
      )
    end
  end

  context "with an even number of batches" do
    let(:partitions_batches) do
      { 0 => [batch(active_vps: 1), batch(active_vps: 4)], 1 => [batch(active_vps: 2), batch(active_vps: 2)] }
    end

    it { expect(result[:partitions][0][:active_vps]).to eq(min: 1, median: 2.5, max: 4) }
    it { expect(result[:summary][:active_vps]).to eq(min: 1, median: 2.0, max: 4) }
  end

  context "with an odd number of batches" do
    let(:partitions_batches) { { 0 => [batch(active_vps: 4), batch(active_vps: 1), batch(active_vps: 3)] } }

    it { expect(result[:summary][:active_vps]).to eq(min: 1, median: 3.0, max: 4) }
    it { expect(result[:summary][:active_vps][:median]).to be_a(Float) }
  end

  context "with collapsed batches" do
    let(:partitions_batches) do
      {
        0 => [
          batch(active_vps: 4, load_imbalance: 20.0),
          batch(active_vps: 1, load_imbalance: nil, collapsed: true)
        ]
      }
    end

    it "leaves them out of the load imbalance" do
      expect(result[:summary]).to include(collapsed_batches: 1, avg_load_imbalance: 20.0)
    end
  end

  context "when all batches are collapsed" do
    let(:partitions_batches) do
      {
        0 => [
          batch(
            active_vps: 1,
            utilization: 25.0,
            parallelization: 25.0,
            load_imbalance: nil,
            collapsed: true
          )
        ]
      }
    end

    it "scores the balance as the worst case" do
      expect(result[:summary]).to include(avg_load_imbalance: nil, score: 18, verdict: :not_recommended)
    end
  end

  context "when concurrency is below 2" do
    let(:settings) { { concurrency: 1, distribution: :consistent } }
    let(:partitions_batches) { { 0 => [batch(active_vps: 1, utilization: 100.0)], 1 => [] } }

    it { expect(result[:partitions][0]).to include(score: nil, verdict: :not_recommended) }
    it { expect(result[:summary]).to include(score: nil, verdict: :not_recommended) }
    it { expect(result[:partitions][1]).to include(score: nil, verdict: nil) }
  end

  context "when a partition has no batches" do
    let(:partitions_batches) { { 0 => [] } }

    it { expect(result[:partitions][0]).to eq(messages: 0, batches: 0, collapsed_batches: 0, score: nil, verdict: nil) }
    it { expect(result[:summary]).to include(messages: 0, batches: 0, score: nil, verdict: nil) }

    context "with details" do
      let(:details) { true }

      it { expect(result[:partitions][0][:batches_details]).to eq([]) }
    end
  end

  context "with details" do
    let(:details) { true }

    it { expect(result[:partitions][0][:batches_details]).to eq(partitions_batches[0]) }
    it { expect(result[:summary]).not_to have_key(:batches_details) }

    it "deeply freezes the batches details" do
      batch_details = result[:partitions][0][:batches_details]

      expect(batch_details).to be_frozen
      expect(batch_details.first).to be_frozen
      expect(batch_details.first[:group_sizes]).to be_frozen
    end
  end

  context "when scoring" do
    let(:partitions_batches) { { 0 => [batch(active_vps: 4, **stats)] } }

    context "when at the recommended threshold" do
      let(:stats) { { utilization: 25.0 } }

      it { expect(result[:summary]).to include(score: 70, verdict: :recommended) }
    end

    context "when just below the recommended threshold" do
      let(:stats) { { utilization: 97.5, parallelization: 0.0 } }

      it { expect(result[:summary]).to include(score: 69, verdict: :maybe) }
    end

    context "when at the maybe threshold" do
      let(:stats) { { utilization: 25.0, parallelization: 0.0 } }

      it { expect(result[:summary]).to include(score: 40, verdict: :maybe) }
    end

    context "when just below the maybe threshold" do
      let(:stats) { { utilization: 22.5, parallelization: 0.0 } }

      it { expect(result[:summary]).to include(score: 39, verdict: :not_recommended) }
    end

    context "when the load imbalance is above 100%" do
      let(:stats) { { utilization: 0.0, parallelization: 0.0, load_imbalance: 150.0 } }

      it { expect(result[:summary]).to include(score: 10, verdict: :not_recommended) }
    end

    context "with configured thresholds and weights" do
      let(:estimator_config) { Karafka::App.config.consumer_groups.virtual_partitions.estimator }
      let(:original_config) { estimator_config.to_h }
      let(:recommended_score) { 68 }
      let(:maybe_score) { 20 }
      let(:stats) { { utilization: 50.0, parallelization: 80.0, load_imbalance: 10.0 } }

      # One poor batch out of two gives 50% stability
      let(:partitions_batches) do
        { 0 => [batch(active_vps: 4, **stats), batch(active_vps: 1, **stats)] }
      end

      before do
        original_config
        estimator_config.recommended_score = recommended_score
        estimator_config.maybe_score = maybe_score
        estimator_config.score_weights.utilization = 10
        estimator_config.score_weights.parallelization = 20
        estimator_config.score_weights.balance = 30
        estimator_config.score_weights.stability = 40
      end

      after do
        estimator_config.recommended_score = original_config[:recommended_score]
        estimator_config.maybe_score = original_config[:maybe_score]

        original_config[:score_weights].each do |name, weight|
          estimator_config.score_weights.public_send(:"#{name}=", weight)
        end
      end

      it "uses all the configured weights" do
        expect(result[:summary]).to include(score: 68, verdict: :recommended)
      end

      context "when the score is below the configured maybe score" do
        let(:recommended_score) { 70 }
        let(:maybe_score) { 69 }

        it { expect(result[:summary]).to include(score: 68, verdict: :not_recommended) }
      end
    end
  end
end
