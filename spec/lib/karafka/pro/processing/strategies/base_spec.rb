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
  subject(:runner) do
    mod = described_class

    klass = Class.new do
      include mod
    end

    klass.new
  end

  describe '#handle_before_schedule_consume' do
    it { expect { runner.handle_before_schedule_consume }.to raise_error(NotImplementedError) }
  end

  describe '#handle_before_consume' do
    it { expect { runner.handle_before_consume }.to raise_error(NotImplementedError) }
  end

  describe '#handle_after_consume' do
    it { expect { runner.handle_after_consume }.to raise_error(NotImplementedError) }
  end

  describe '#handle_before_schedule_revoked' do
    it { expect { runner.handle_before_schedule_revoked }.to raise_error(NotImplementedError) }
  end

  describe '#handle_revoked' do
    it { expect { runner.handle_revoked }.to raise_error(NotImplementedError) }
  end

  describe '#handle_before_schedule_shutdown' do
    it { expect { runner.handle_before_schedule_shutdown }.to raise_error(NotImplementedError) }
  end

  describe '#handle_shutdown' do
    it { expect { runner.handle_shutdown }.to raise_error(NotImplementedError) }
  end

  describe '#handle_before_schedule_idle' do
    it { expect { runner.handle_before_schedule_idle }.to raise_error(NotImplementedError) }
  end

  describe '#handle_idle' do
    it { expect { runner.handle_idle }.to raise_error(NotImplementedError) }
  end
end
