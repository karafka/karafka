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
  subject(:check) { described_class.new.call(pattern) }

  let(:pattern) { { regexp: /.*/, name: 'xda', regexp_string: '^xda' } }

  context 'when config is valid' do
    it { expect(check).to be_success }
  end

  context 'when regexp is not a regexp' do
    before { pattern[:regexp] = 'na' }

    it { expect(check).not_to be_success }
  end

  context 'when regexp is missing' do
    before { pattern.delete(:regexp) }

    it { expect(check).not_to be_success }
  end

  context 'when regexp is not a Regexp' do
    before { pattern[:regexp] = 'not_a_regexp' }

    it { expect(check).not_to be_success }
  end

  context 'when name is missing' do
    before { pattern.delete(:name) }

    it { expect(check).not_to be_success }
  end

  context 'when name is not a string' do
    before { pattern[:name] = 123 }

    it { expect(check).not_to be_success }
  end

  context 'when name is an invalid string' do
    before { pattern[:name] = '%^&*(' }

    it { expect(check).not_to be_success }
  end

  context 'when regexp string does not start with ^' do
    before { pattern[:regexp_string] = 'test' }

    it { expect(check).not_to be_success }
  end

  context 'when regexp string is only ^' do
    before { pattern[:regexp_string] = '^' }

    it { expect(check).not_to be_success }
  end

  context 'when regexp_string is missing' do
    before { pattern.delete(:regexp_string) }

    it { expect(check).not_to be_success }
  end
end
