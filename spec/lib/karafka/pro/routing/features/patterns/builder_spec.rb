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
  subject(:builder) do
    Karafka::Routing::Builder.new.tap do |builder|
      builder.singleton_class.prepend described_class
    end
  end

  let(:cg) { builder.first }

  describe '#pattern' do
    context 'when defining pattern without any extra settings' do
      before do
        builder.pattern(/test/) do
          consumer Class.new
        end
      end

      it { expect(cg.topics.first.name).to include('karafka-pattern') }
      it { expect(cg.topics.first.consumer).not_to be_nil }
      it { expect(cg.patterns.first.regexp).to eq(/test/) }
    end

    context 'when defining named pattern without any extra settings' do
      before do
        builder.pattern('my-name', /test/) do
          consumer Class.new
        end
      end

      it { expect(cg.topics.first.name).to eq('my-name') }
      it { expect(cg.topics.first.consumer).not_to be_nil }
      it { expect(cg.patterns.first.regexp).to eq(/test/) }
    end

    context 'when defining pattern with extra settings' do
      before do
        builder.pattern(/test/) do
          consumer Class.new
          manual_offset_management(true)
        end
      end

      it { expect(cg.topics.first.manual_offset_management?).to be(true) }
    end

    context 'when defining named pattern with extra settings' do
      before do
        builder.pattern('my-name', /test/) do
          consumer Class.new
          manual_offset_management(true)
        end
      end

      it { expect(cg.topics.first.manual_offset_management?).to be(true) }
      it { expect(cg.topics.first.name).to eq('my-name') }
    end
  end
end
