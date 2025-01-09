# frozen_string_literal: true
#
# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
