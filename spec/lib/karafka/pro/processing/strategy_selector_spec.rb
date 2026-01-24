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
  subject(:selected_strategy) { described_class.new.find(topic) }

  let(:topic) { build(:routing_topic) }

  context 'when no features enabled' do
    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Default) }
  end

  context 'when manual offset management is on' do
    before { topic.manual_offset_management(true) }

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Mom::Default) }
  end

  context 'when virtual partitions are on' do
    before { topic.virtual_partitions(partitioner: true) }

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Vp::Default) }
  end

  context 'when lrj is enabled with vp' do
    before do
      topic.long_running_job(true)
      topic.virtual_partitions(partitioner: true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Lrj::Vp) }
  end

  context 'when lrj is enabled with mom' do
    before do
      topic.long_running_job(true)
      topic.manual_offset_management(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Lrj::Mom) }
  end

  context 'when lrj is enabled with mom and thg' do
    before do
      topic.long_running_job(true)
      topic.manual_offset_management(true)
      topic.throttling(limit: 5, interval: 100)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Lrj::FtrMom) }
  end

  context 'when lrj is enabled' do
    before { topic.long_running_job(true) }

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Lrj::Default) }
  end

  context 'when aj is enabled with mom and vp' do
    before do
      topic.active_job(true)
      topic.manual_offset_management(true)
      topic.virtual_partitions(partitioner: true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Aj::MomVp) }
  end

  context 'when aj is enabled with mom and thg' do
    before do
      topic.active_job(true)
      topic.manual_offset_management(true)
      topic.throttling(limit: 5, interval: 100)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Aj::FtrMom) }
  end

  context 'when aj is enabled with mom, thg and vp' do
    before do
      topic.active_job(true)
      topic.manual_offset_management(true)
      topic.throttling(limit: 5, interval: 100)
      topic.virtual_partitions(partitioner: true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Aj::FtrMomVp) }
  end

  context 'when aj is enabled with lrj, mom, thg and vp' do
    before do
      topic.active_job(true)
      topic.dead_letter_queue(topic: 'test')
      topic.long_running_job(true)
      topic.manual_offset_management(true)
      topic.throttling(limit: 5, interval: 100)
      topic.virtual_partitions(partitioner: true)
    end

    it do
      expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Aj::DlqFtrLrjMomVp)
    end
  end

  context 'when aj is enabled with mom' do
    before do
      topic.active_job(true)
      topic.manual_offset_management(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Aj::Mom) }
  end

  context 'when aj is enabled with lrj, mom and vp' do
    before do
      topic.active_job(true)
      topic.manual_offset_management(true)
      topic.long_running_job(true)
      topic.virtual_partitions(partitioner: true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Aj::LrjMomVp) }
  end

  context 'when aj is enabled with lrj and mom' do
    before do
      topic.active_job(true)
      topic.manual_offset_management(true)
      topic.long_running_job(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Aj::LrjMom) }
  end

  context 'when aj is enabled with lrj, mom and thg' do
    before do
      topic.active_job(true)
      topic.long_running_job(true)
      topic.manual_offset_management(true)
      topic.throttling(limit: 5, interval: 100)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Aj::FtrLrjMom) }
  end

  context 'when aj is enabled with lrj, mom and ftr' do
    before do
      topic.active_job(true)
      topic.long_running_job(true)
      topic.manual_offset_management(true)
      topic.filter -> {}
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Aj::FtrLrjMom) }
  end

  context 'when we enable not supported combination' do
    before do
      topic.active_job(true)
      topic.long_running_job(true)
    end

    it { expect { selected_strategy }.to raise_error(Karafka::Errors::StrategyNotFoundError) }
  end

  context 'when dlq is enabled' do
    before { topic.dead_letter_queue(topic: 'test') }

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Dlq::Default) }
  end

  context 'when dlq with vp is enabled' do
    before do
      topic.dead_letter_queue(topic: 'test')
      topic.virtual_partitions(partitioner: true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Dlq::Vp) }
  end

  context 'when dlq with mom is enabled' do
    before do
      topic.dead_letter_queue(topic: 'test')
      topic.manual_offset_management(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Dlq::Mom) }
  end

  context 'when dlq, mom and lrj is enabled' do
    before do
      topic.dead_letter_queue(topic: 'test')
      topic.manual_offset_management(true)
      topic.long_running_job(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Dlq::LrjMom) }
  end

  context 'when dlq, mom, lrj and thg is enabled' do
    before do
      topic.dead_letter_queue(topic: 'test')
      topic.manual_offset_management(true)
      topic.long_running_job(true)
      topic.throttling(limit: 100, interval: 100)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Dlq::FtrLrjMom) }
  end

  context 'when dlq, lrj and thg is enabled' do
    before do
      topic.dead_letter_queue(topic: 'test')
      topic.long_running_job(true)
      topic.throttling(limit: 100, interval: 100)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Dlq::FtrLrj) }
  end

  context 'when dlq, lrj, vp and thg is enabled' do
    before do
      topic.dead_letter_queue(topic: 'test')
      topic.long_running_job(true)
      topic.throttling(limit: 100, interval: 100)
      topic.virtual_partitions(partitioner: true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Dlq::FtrLrjVp) }
  end

  context 'when dlq and thg' do
    before do
      topic.dead_letter_queue(topic: 'test')
      topic.throttling(limit: 100, interval: 100)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Dlq::Ftr) }
  end

  context 'when dlq, thg and vps' do
    before do
      topic.dead_letter_queue(topic: 'test')
      topic.throttling(limit: 100, interval: 100)
      topic.virtual_partitions(partitioner: true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Dlq::FtrVp) }
  end

  context 'when aj, dlq and mom is enabled' do
    before do
      topic.dead_letter_queue(topic: 'test')
      topic.manual_offset_management(true)
      topic.active_job(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Aj::DlqMom) }
  end

  context 'when aj, dlq, mom and thg is enabled' do
    before do
      topic.active_job(true)
      topic.dead_letter_queue(topic: 'test')
      topic.manual_offset_management(true)
      topic.throttling(limit: 100, interval: 100)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Aj::DlqFtrMom) }
  end

  context 'when aj, dlq, mom, thg and vp is enabled' do
    before do
      topic.active_job(true)
      topic.dead_letter_queue(topic: 'test')
      topic.manual_offset_management(true)
      topic.throttling(limit: 100, interval: 100)
      topic.virtual_partitions(partitioner: true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Aj::DlqFtrMomVp) }
  end

  context 'when aj, dlq, mom and vp is enabled' do
    before do
      topic.virtual_partitions(partitioner: true)
      topic.dead_letter_queue(topic: 'test')
      topic.manual_offset_management(true)
      topic.active_job(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Aj::DlqMomVp) }
  end

  context 'when aj, dlq, mom and lrj is enabled' do
    before do
      topic.dead_letter_queue(topic: 'test')
      topic.manual_offset_management(true)
      topic.long_running_job(true)
      topic.active_job(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Aj::DlqLrjMom) }
  end

  context 'when thg and vps are enabled' do
    before do
      topic.virtual_partitions(partitioner: true)
      topic.throttling(limit: 100, interval: 100)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Ftr::Vp) }
  end

  context 'when mom and thg are enabled' do
    before do
      topic.manual_offset_management(true)
      topic.throttling(limit: 100, interval: 100)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Mom::Ftr) }
  end

  context 'when lrj and thg are enabled' do
    before do
      topic.long_running_job(true)
      topic.throttling(limit: 100, interval: 100)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Lrj::Ftr) }
  end

  # Those specs make sure, that every expected features combination has a matching strategy
  # That way when we add a new feature, we can ensure, that all the combinations of features are
  # usable with it or that a given combination is one of the not supported or not needed
  #
  # We also need to prevent a case where a given combination would be defined twice by mistake, etc
  describe 'strategies presence vs. features combinations' do
    subject(:selector) { described_class.new }

    # Combinations that for any reason are not supported
    let(:not_used_combinations) do
      [
        # Active Job is always with manual offset management in any combination
        # ActiveJob sets MoM automatically and there is no way to end-up with a combination
        # that would not have MoM
        %i[active_job],
        %i[active_job dead_letter_queue],
        %i[active_job dead_letter_queue filtering],
        %i[active_job dead_letter_queue virtual_partitions],
        %i[active_job dead_letter_queue long_running_job],
        %i[active_job dead_letter_queue filtering virtual_partitions],
        %i[active_job dead_letter_queue long_running_job filtering],
        %i[active_job dead_letter_queue long_running_job virtual_partitions],
        %i[active_job dead_letter_queue long_running_job virtual_partitions filtering],
        %i[active_job long_running_job],
        %i[active_job long_running_job filtering],
        %i[active_job long_running_job filtering virtual_partitions],
        %i[active_job virtual_partitions],
        %i[active_job virtual_partitions filtering],
        %i[active_job filtering],
        %i[active_job long_running_job virtual_partitions]
      ]
    end

    let(:combinations) do
      combinations = []

      features = described_class::SUPPORTED_FEATURES

      features.size.times.each do |i|
        combinations += features.combination(i + 1).to_a
      end

      combinations.each(&:sort!)
      combinations.uniq!
      combinations
    end

    it 'expect each features combination to be supported expect the explicitly ignored' do
      aggro = []

      combinations.each do |combination|
        matching_strategies = selector.strategies.select do |strategy|
          strategy::FEATURES.sort == combination
        end

        next if not_used_combinations.any? { |not_used| not_used.sort == combination }

        aggro << combination if matching_strategies.empty?

        # Each combination of features should always have one matching strategy
        # expect(matching_strategies.size).to eq(1), combination.to_s
      end

      expect(aggro).to eq([])
    end
  end
end
