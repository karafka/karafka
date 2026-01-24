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
  subject(:message) { build(:messages_message) }

  describe '#payload' do
    context 'when message was not cleaned' do
      it { expect { message.payload }.not_to raise_error }
    end

    context 'when message was cleaned' do
      let(:expected_error) { Karafka::Pro::Cleaner::Errors::MessageCleanedError }

      before { message.clean! }

      it { expect { message.payload }.to raise_error(expected_error) }
    end
  end

  describe '#cleaned? and #clean!' do
    context 'when message was not cleaned' do
      it { expect(message.cleaned?).to be(false) }
      it { expect(message.raw_payload).not_to be(false) }
      it { expect(message.deserialized?).to be(false) }
    end

    context 'when message was cleaned' do
      before { message.clean! }

      it { expect(message.cleaned?).to be(true) }
      it { expect(message.deserialized?).to be(false) }
      it { expect(message.raw_payload).to be(false) }
      it { expect(message.metadata.cleaned?).to be(true) }
    end

    context 'when message was cleaned with metadata cleaning disabled' do
      before { message.clean!(metadata: false) }

      it { expect(message.cleaned?).to be(true) }
      it { expect(message.deserialized?).to be(false) }
      it { expect(message.raw_payload).to be(false) }
      it { expect(message.metadata.cleaned?).to be(false) }
      it { expect(message.metadata.key).to be_nil }
      it { expect(message.metadata.headers).to eq({}) }
    end

    context 'when message was deserialized and cleaned' do
      before do
        message.payload
        message.clean!
      end

      it { expect(message.cleaned?).to be(true) }
      it { expect(message.deserialized?).to be(false) }
      it { expect(message.raw_payload).to be(false) }
    end
  end
end
