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
  subject(:executor) { described_class.new(group_id, client, coordinator) }

  let(:group_id) { rand.to_s }
  let(:client) { instance_double(Karafka::Connection::Client) }
  let(:coordinator) { build(:processing_coordinator) }
  let(:topic) { coordinator.topic }
  let(:messages) { [build(:messages_message)] }
  let(:coordinator) { build(:processing_coordinator) }
  let(:consumer) do
    ClassBuilder.inherit(topic.consumer) do
      def consume; end
    end.new
  end

  before { allow(topic.consumer).to receive(:new).and_return(consumer) }

  describe '#before_schedule_periodic' do
    before { allow(consumer).to receive(:on_before_schedule_tick) }

    it do
      expect { executor.before_schedule_periodic }.not_to raise_error
    end

    it 'expect to run consumer on_before_schedule' do
      executor.before_schedule_periodic
      expect(consumer).to have_received(:on_before_schedule_tick).with(no_args)
    end
  end

  describe '#periodic' do
    before do
      allow(consumer).to receive(:on_tick)
      executor.periodic
    end

    it 'expect to run consumer on_tick' do
      expect(consumer).to have_received(:on_tick).with(no_args)
    end
  end
end
