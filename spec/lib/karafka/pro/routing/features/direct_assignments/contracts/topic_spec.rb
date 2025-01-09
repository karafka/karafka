# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

RSpec.describe_current do
  subject(:validation_result) { described_class.new.call(config) }

  context 'with valid configurations' do
    let(:config) do
      {
        direct_assignments: {
          active: true,
          partitions: { 1 => true, 2 => true }
        },
        swarm: {
          active: false
        },
        patterns: {
          active: false
        }
      }
    end

    it 'is expected to be successful' do
      expect(validation_result).to be_success
    end
  end

  context 'when active is not a boolean' do
    let(:config) do
      {
        direct_assignments: {
          active: 'true', # Invalid type
          partitions: { 1 => true }
        },
        swarm: {
          active: false
        },
        patterns: {
          active: false
        }
      }
    end

    it 'is expected to fail' do
      expect(validation_result).not_to be_success
    end
  end

  context 'when partitions are not exclusively integers mapping to true' do
    let(:config) do
      {
        direct_assignments: {
          active: true,
          partitions: { '1' => true, 2 => false } # Invalid key type and value
        },
        swarm: {
          active: false
        },
        patterns: {
          active: false
        }
      }
    end

    it 'is expected to fail' do
      expect(validation_result).not_to be_success
    end
  end

  context 'when partitions are set to true' do
    let(:config) do
      {
        direct_assignments: {
          active: true,
          partitions: true
        },
        swarm: {
          active: false
        },
        patterns: {
          active: false
        }
      }
    end

    it 'is expected to be successful' do
      expect(validation_result).to be_success
    end
  end

  context 'when partitions is an empty hash' do
    let(:config) do
      {
        direct_assignments: {
          active: true,
          partitions: {} # Empty hash is not valid
        },
        swarm: {
          active: false
        },
        patterns: {
          active: false
        }
      }
    end

    it 'is expected to fail' do
      expect(validation_result).not_to be_success
    end
  end

  context 'when we assigned more partitions than allocated in swarm' do
    let(:config) do
      {
        direct_assignments: {
          active: true,
          partitions: { 0 => true, 1 => true, 2 => true, 3 => true }
        },
        swarm: {
          active: true,
          nodes: { 0 => [0], 1 => [1] }
        },
        patterns: {
          active: false
        }
      }
    end

    it { expect(validation_result).not_to be_success }
  end

  context 'when we allocated more partitions than assigned' do
    let(:config) do
      {
        direct_assignments: {
          active: true,
          partitions: { 0 => true, 1 => true, 2 => true }
        },
        swarm: {
          active: true,
          nodes: { 0 => [0], 1 => [1, 2, 3] }
        },
        patterns: {
          active: false
        }
      }
    end

    it { expect(validation_result).not_to be_success }
  end

  context 'when direct assignments are used with patterns' do
    let(:config) do
      {
        direct_assignments: {
          active: true,
          partitions: true
        },
        swarm: {
          active: false
        },
        patterns: {
          active: true
        }
      }
    end

    it 'is expected to fail' do
      expect(validation_result).not_to be_success
    end
  end
end
