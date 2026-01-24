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
  subject(:check) { described_class.new.call(config) }

  let(:config) do
    {
      parallel_segments: {
        active: true,
        partitioner: ->(message) { message.key },
        reducer: ->(messages) { messages.last },
        count: 5,
        merge_key: 'user_id'
      }
    }
  end

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when we check for the errors yml file reference' do
    it 'expect to have all of them defined' do
      stringified = described_class.config.error_messages.to_s
      described_class.rules.each do |rule|
        expect(stringified).to include(rule.path.last.to_s)
      end
    end
  end

  context 'when validating active flag' do
    context 'when active is not a boolean' do
      before { config[:parallel_segments][:active] = nil }

      it { expect(check).not_to be_success }
    end

    context 'when active is a boolean' do
      before { config[:parallel_segments][:active] = false }

      it { expect(check).to be_success }
    end
  end

  context 'when validating partitioner' do
    context 'when parallel segments are active' do
      before { config[:parallel_segments][:active] = true }

      context 'when partitioner is nil' do
        before { config[:parallel_segments][:partitioner] = nil }

        it { expect(check).not_to be_success }
      end

      context 'when partitioner does not respond to call' do
        before { config[:parallel_segments][:partitioner] = 'invalid' }

        it { expect(check).not_to be_success }
      end

      context 'when partitioner responds to call' do
        before { config[:parallel_segments][:partitioner] = -> {} }

        it { expect(check).to be_success }
      end
    end

    context 'when parallel segments are not active' do
      before do
        config[:parallel_segments][:active] = false
        config[:parallel_segments][:partitioner] = nil
      end

      it { expect(check).to be_success }
    end
  end

  context 'when validating reducer' do
    context 'when reducer does not respond to call' do
      before { config[:parallel_segments][:reducer] = 'invalid' }

      it { expect(check).not_to be_success }
    end

    context 'when reducer responds to call' do
      before { config[:parallel_segments][:reducer] = -> {} }

      it { expect(check).to be_success }
    end
  end

  context 'when validating count' do
    context 'when count is not an integer' do
      before { config[:parallel_segments][:count] = 'invalid' }

      it { expect(check).not_to be_success }
    end

    context 'when count is less than 1' do
      before { config[:parallel_segments][:count] = 0 }

      it { expect(check).not_to be_success }
    end

    context 'when count is 1 or greater' do
      before { config[:parallel_segments][:count] = 1 }

      it { expect(check).to be_success }
    end
  end

  context 'when validating merge_key' do
    context 'when merge_key is not a string' do
      before { config[:parallel_segments][:merge_key] = :symbol }

      it { expect(check).not_to be_success }
    end

    context 'when merge_key is an empty string' do
      before { config[:parallel_segments][:merge_key] = '' }

      it { expect(check).not_to be_success }
    end

    context 'when merge_key is a non-empty string' do
      before { config[:parallel_segments][:merge_key] = 'key' }

      it { expect(check).to be_success }
    end
  end
end
