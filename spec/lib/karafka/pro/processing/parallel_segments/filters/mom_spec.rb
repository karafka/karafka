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
  subject(:filter) do
    described_class.new(
      segment_id: segment_id,
      partitioner: partitioner,
      reducer: reducer
    )
  end

  let(:segment_id) { 1 }
  let(:count) { 2 }
  let(:partitioner) { ->(message) { message.key } }
  let(:reducer) { ->(parallel_key) { parallel_key.to_s.sum % count } }

  # Messages with raw_key that will distribute to expected groups with our reducer
  let(:message1) { build(:messages_message, raw_key: "key2") } # Goes to group 1
  let(:message2) { build(:messages_message, raw_key: "key1") } # Goes to group 0
  let(:message3) { build(:messages_message, raw_key: "key4") } # Goes to group 1
  let(:message4) { build(:messages_message, raw_key: "key3") } # Goes to group 0

  context "when there are no messages" do
    let(:messages) { [] }

    before { filter.apply!(messages) }

    it { expect(filter.applied?).to be(false) }
    it { expect(filter.mark_as_consumed?).to be(false) }
    it { expect(filter.action).to eq(:skip) }
    it { expect(filter.timeout).to be_nil }
  end

  context "when all messages belong to our group" do
    let(:messages) { [message1, message3] }

    before { filter.apply!(messages) }

    it { expect(filter.applied?).to be(false) }
    it { expect(filter.mark_as_consumed?).to be(false) }
    it { expect(filter.action).to eq(:skip) }
    it { expect(messages).to eq([message1, message3]) }
  end

  context "when no messages belong to our group" do
    let(:messages) { [message2, message4] }

    before { filter.apply!(messages) }

    it { expect(filter.applied?).to be(true) }
    # Key difference from Default filter - Mom never marks as consumed
    it { expect(filter.mark_as_consumed?).to be(false) }
    it { expect(filter.action).to eq(:skip) }
    it { expect(filter.marking_method).to eq(:mark_as_consumed) }
    it { expect(messages).to be_empty }
  end

  context "when some messages belong to our group" do
    let(:messages) { [message1, message2, message3, message4] }

    before { filter.apply!(messages) }

    it { expect(filter.applied?).to be(true) }
    it { expect(filter.mark_as_consumed?).to be(false) }
    it { expect(filter.action).to eq(:skip) }
    it { expect(messages).to eq([message1, message3]) }
  end

  context "when using a different segment_id" do
    let(:segment_id) { 0 }
    let(:messages) { [message1, message2, message3, message4] }

    before { filter.apply!(messages) }

    it { expect(filter.applied?).to be(true) }
    it { expect(filter.mark_as_consumed?).to be(false) }
    it { expect(filter.action).to eq(:skip) }
    it { expect(messages).to eq([message2, message4]) }
  end

  context "with a more complex partitioner and reducer" do
    let(:count) { 3 }
    let(:partitioner) { ->(message) { message.headers["segment_count"] } }

    # Goes to group 2
    let(:message1) do
      build(:messages_message, raw_key: "key1", raw_headers: { "segment_count" => "5" })
    end

    # Goes to group 0
    let(:message2) do
      build(:messages_message, raw_key: "key2", raw_headers: { "segment_count" => "3" })
    end

    # Goes to group 2
    let(:message3) do
      build(:messages_message, raw_key: "key3", raw_headers: { "segment_count" => "8" })
    end

    # Goes to group 1
    let(:message4) do
      build(:messages_message, raw_key: "key4", raw_headers: { "segment_count" => "4" })
    end

    let(:segment_id) { 2 }
    let(:messages) { [message1, message2, message3, message4] }

    before { filter.apply!(messages) }

    it { expect(filter.applied?).to be(true) }
    it { expect(filter.mark_as_consumed?).to be(false) }
    it { expect(messages).to eq([message1, message3]) }
  end

  describe "marking behavior" do
    context "when all messages belong to our group" do
      let(:messages) { [message1, message3] }

      before { filter.apply!(messages) }

      it { expect(filter.mark_as_consumed?).to be(false) }
    end

    context "when all messages are filtered out" do
      let(:messages) { [message2, message4] }

      before { filter.apply!(messages) }

      # Key difference from Default filter - Mom never marks as consumed
      it { expect(filter.mark_as_consumed?).to be(false) }
      it { expect(filter.marking_method).to eq(:mark_as_consumed) }
    end

    context "when no messages were in batch" do
      let(:messages) { [] }

      before { filter.apply!(messages) }

      it { expect(filter.mark_as_consumed?).to be(false) }
    end
  end

  describe "interface methods" do
    # Test all methods required by the filter interface
    it { expect(filter).to respond_to(:apply!) }
    it { expect(filter).to respond_to(:applied?) }
    it { expect(filter).to respond_to(:mark_as_consumed?) }
    it { expect(filter).to respond_to(:marking_method) }
    it { expect(filter).to respond_to(:action) }
    it { expect(filter).to respond_to(:timeout) }

    context "with empty messages" do
      before { filter.apply!([]) }

      it { expect(filter.action).to eq(:skip) }
      it { expect(filter.timeout).to be_nil }
      it { expect(filter.marking_method).to eq(:mark_as_consumed) }
    end

    context "with all filtered messages" do
      before { filter.apply!([message2, message4]) }

      it { expect(filter.action).to eq(:skip) }
      it { expect(filter.timeout).to be_nil }
      # Key difference - Mom never marks as consumed
      it { expect(filter.mark_as_consumed?).to be(false) }
    end
  end

  describe "applied flag" do
    context "when no filtering occurred" do
      let(:messages) { [message1, message3] }

      before { filter.apply!(messages) }

      it { expect(filter.applied?).to be(false) }
    end

    context "when filtering occurred" do
      let(:messages) { [message1, message2] }

      before { filter.apply!(messages) }

      it { expect(filter.applied?).to be(true) }
    end

    context "when setting @apply instead of @applied" do
      let(:messages) { [message2] }

      it "still reports applied? correctly" do
        # This test ensures we catch the bug where @apply is set but @applied is checked
        filter.apply!(messages)
        expect(filter.applied?).to be(true)
      end
    end
  end

  describe "special cases" do
    context "with nil key" do
      let(:nil_key_message) { build(:messages_message, raw_key: nil) }
      let(:messages) { [nil_key_message] }

      it "does not raise error" do
        expect { filter.apply!(messages) }.not_to raise_error
      end
    end

    context "with different count values" do
      [2, 3, 5, 10].each do |c|
        context "with count = #{c}" do
          let(:count) { c }
          let(:messages) { [message1, message2, message3, message4] }

          before { filter.apply!(messages) }

          it "filters according to the distribution pattern" do
            # Calculate expected result based on our reducer formula
            expected = messages.select do |message|
              message.key.to_s.sum % count == segment_id
            end

            expect(messages).to match_array(expected)
          end
        end
      end
    end

    context "with messages in non-sequential order" do
      let(:messages) { [message4, message2, message3, message1] }

      before { filter.apply!(messages) }

      it "correctly filters based on group assignment" do
        expect(messages).to contain_exactly(message1, message3)
      end
    end
  end

  # Test that highlights the key difference between Default and Mom filters
  describe "mom-specific behavior" do
    context "when all messages are filtered out" do
      let(:messages) { [message2, message4] }

      before { filter.apply!(messages) }

      it "never marks as consumed regardless of filtering result" do
        expect(filter.mark_as_consumed?).to be(false)
      end
    end
  end
end
