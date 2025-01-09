# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:validation_result) { described_class.new.call(config) }

  context 'with all topics using direct assignments' do
    let(:config) do
      {
        topics: [
          { direct_assignments: { active: true } },
          { direct_assignments: { active: true } }
        ]
      }
    end

    it 'is expected to be successful' do
      expect(validation_result).to be_success
    end
  end

  context 'with no topics using direct assignments' do
    let(:config) do
      {
        topics: [
          { direct_assignments: { active: false } },
          { direct_assignments: { active: false } }
        ]
      }
    end

    it 'is expected to be successful' do
      expect(validation_result).to be_success
    end
  end

  context 'with a mix of topics using and not using direct assignments' do
    let(:config) do
      {
        topics: [
          { direct_assignments: { active: true } },
          { direct_assignments: { active: false } }
        ]
      }
    end

    it 'is expected to fail' do
      expect(validation_result).not_to be_success
    end
  end

  context 'with a single topic' do
    context 'when using direct assignments' do
      let(:config) do
        {
          topics: [
            { direct_assignments: { active: true } }
          ]
        }
      end

      it 'is expected to be successful' do
        expect(validation_result).to be_success
      end
    end

    context 'when not using direct assignments' do
      let(:config) do
        {
          topics: [
            { direct_assignments: { active: false } }
          ]
        }
      end

      it 'is expected to be successful' do
        expect(validation_result).to be_success
      end
    end
  end
end
