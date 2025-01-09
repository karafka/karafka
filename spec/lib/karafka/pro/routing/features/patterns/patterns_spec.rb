# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:patterns) { described_class.new([]) }

  let(:pattern_class) { Karafka::Pro::Routing::Features::Patterns::Pattern }

  describe '#find' do
    let(:topic_name) { 'test_topic' }
    let(:matching_pattern) { pattern_class.new(nil, /test_/, -> {}) }
    let(:non_matching_pattern) { pattern_class.new(nil, /not_matching_/, -> {}) }

    before do
      patterns << non_matching_pattern
      patterns << matching_pattern
    end

    it 'expects to find a pattern matching the topic name' do
      expect(patterns.find(topic_name)).to eq(matching_pattern)
    end

    context 'when multiple patterns match' do
      let(:another_matching_pattern) { pattern_class.new(nil, /_topic/, -> {}) }

      before { patterns << another_matching_pattern }

      it 'expects to return the first matching pattern' do
        expect(patterns.find(topic_name)).to eq(matching_pattern)
      end
    end

    context 'when no pattern matches' do
      let(:topic_name) { 'unmatched_topic' }

      it { expect(patterns.find(topic_name)).to be_nil }
    end
  end
end
