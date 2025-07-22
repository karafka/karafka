# frozen_string_literal: true

RSpec.describe_current do
  let(:resource_type) { :topic }
  let(:resource_name) { "it-#{SecureRandom.uuid}" }
  let(:resource_pattern_type) { :literal }
  let(:principal) { 'User:*' }
  let(:host) { '*' }
  let(:operation) { :all }
  let(:permission_type) { :any }
  let(:acl) { described_class.new(**defaults) }
  let(:defaults) do
    {
      resource_type: resource_type,
      resource_name: resource_name,
      resource_pattern_type: resource_pattern_type,
      principal: principal,
      host: host,
      operation: operation,
      permission_type: permission_type
    }
  end

  describe '#new' do
    context 'when trying to create with attribute that cannot be mapped' do
      let(:resource_type) { :nothing_useful }

      it { expect { acl }.to raise_error(Karafka::Errors::UnsupportedCaseError) }
    end
  end

  describe '#create' do
    subject(:creation) do
      ref = described_class.create(acl)
      sleep(0.2)
      ref
    end

    context 'when creating with invalid arguments' do
      it { expect { creation }.to raise_error(Rdkafka::Config::ConfigError, /Invalid/) }
    end

    context 'when creating with valid arguments on topic' do
      let(:permission_type) { :allow }

      it { expect { creation }.not_to raise_error }
      it { expect { creation }.to change { described_class.all.size }.by(1) }
      it { expect(creation.last.resource_name).to eq(resource_name) }
      it { expect(creation.last.resource_type).to eq(resource_type) }
    end

    context 'when creating with valid arguments on consumer group' do
      let(:resource_type) { :consumer_group }
      let(:permission_type) { :allow }

      it { expect { creation }.not_to raise_error }
      it { expect { creation }.to change { described_class.all.size }.by(1) }
      it { expect(creation.last.resource_name).to eq(resource_name) }
      it { expect(creation.last.resource_type).to eq(resource_type) }
    end

    context 'when creating with valid arguments on transactional id' do
      let(:resource_type) { :transactional_id }
      let(:permission_type) { :allow }

      it { expect { creation }.not_to raise_error }
      it { expect { creation }.to change { described_class.all.size }.by(1) }
      it { expect(creation.last.resource_name).to eq(resource_name) }
      it { expect(creation.last.resource_type).to eq(resource_type) }
    end
  end

  describe '#delete' do
    subject(:deletion) do
      ref = described_class.delete(acl)
      # This is needed as those operations are async
      sleep(0.2)
      ref
    end

    context 'when deleting with invalid arguments' do
      it { expect { deletion }.not_to raise_error }
    end

    context 'when deleting with valid acl created on a topic' do
      let(:permission_type) { :allow }

      before { described_class.create(acl) }

      it { expect { deletion }.not_to raise_error }
      it { expect { deletion }.to change { described_class.all.size }.by(-1) }
      it { expect(deletion.last.resource_name).to eq(resource_name) }
      it { expect(deletion.last.resource_type).to eq(resource_type) }
      it { expect(deletion.size).to eq(1) }
    end

    context 'when deleting with valid acl created on a consumer group' do
      let(:resource_type) { :consumer_group }
      let(:permission_type) { :allow }

      before { described_class.create(acl) }

      it { expect { deletion }.not_to raise_error }
      it { expect { deletion }.to change { described_class.all.size }.by(-1) }
      it { expect(deletion.last.resource_name).to eq(resource_name) }
      it { expect(deletion.last.resource_type).to eq(resource_type) }
      it { expect(deletion.size).to eq(1) }
    end

    context 'when deleting with valid acl with multiple topic acls existing' do
      let(:permission_type) { :any }

      let(:acl1) do
        config = defaults.dup
        config[:permission_type] = :allow
        described_class.new(**config)
      end

      let(:acl2) do
        config = defaults.dup
        config[:permission_type] = :deny
        described_class.new(**config)
      end

      before do
        described_class.create(acl1)
        described_class.create(acl2)
      end

      it { expect { deletion }.not_to raise_error }
      it { expect { deletion }.to change { described_class.all.size }.by(-2) }
      it { expect(deletion.last.resource_name).to eq(resource_name) }
      it { expect(deletion.last.resource_type).to eq(resource_type) }
      it { expect(deletion.size).to eq(2) }
    end

    context 'when deleting with valid acl created on a transactional id' do
      let(:resource_type) { :transactional_id }
      let(:permission_type) { :allow }

      before { described_class.create(acl) }

      it { expect { deletion }.not_to raise_error }
      it { expect { deletion }.to change { described_class.all.size }.by(-1) }
      it { expect(deletion.last.resource_name).to eq(resource_name) }
      it { expect(deletion.last.resource_type).to eq(resource_type) }
      it { expect(deletion.size).to eq(1) }
    end

    context 'when deleting with valid acl with multiple transactional id acls existing' do
      let(:resource_type) { :transactional_id }
      let(:permission_type) { :any }

      let(:acl1) do
        config = defaults.dup
        config[:resource_type] = :transactional_id
        config[:permission_type] = :allow
        described_class.new(**config)
      end

      let(:acl2) do
        config = defaults.dup
        config[:resource_type] = :transactional_id
        config[:permission_type] = :deny
        described_class.new(**config)
      end

      before do
        described_class.create(acl1)
        described_class.create(acl2)
      end

      it { expect { deletion }.not_to raise_error }
      it { expect { deletion }.to change { described_class.all.size }.by(-2) }
      it { expect(deletion.last.resource_name).to eq(resource_name) }
      it { expect(deletion.last.resource_type).to eq(resource_type) }
      it { expect(deletion.size).to eq(2) }
    end
  end

  describe '#describe' do
    let(:describing) { described_class.describe(acl) }
    let(:permission_type) { :any }

    let(:acl1) do
      config = defaults.dup
      config[:permission_type] = :allow
      described_class.new(**config)
    end

    let(:acl2) do
      config = defaults.dup
      config[:permission_type] = :deny
      described_class.new(**config)
    end

    context 'when trying to describe an acl that does not match' do
      it { expect(describing).to eq([]) }
    end

    context 'when trying to describe an acl that matches one' do
      before { described_class.create(acl1) }

      it { expect(describing.size).to eq(1) }
    end

    context 'when trying to describe an acl that matches many' do
      before do
        described_class.create(acl1)
        described_class.create(acl2)
      end

      it { expect(describing.size).to eq(2) }
    end

    context 'when trying to describe transactional id acl that matches one' do
      let(:resource_type) { :transactional_id }
      let(:acl1) do
        config = defaults.dup
        config[:resource_type] = :transactional_id
        config[:permission_type] = :allow
        described_class.new(**config)
      end

      before { described_class.create(acl1) }

      it { expect(describing.size).to eq(1) }
      it { expect(describing.first.resource_type).to eq(:transactional_id) }
      it { expect(describing.first.resource_name).to eq(resource_name) }
    end

    context 'when trying to describe transactional id acl that matches many' do
      let(:resource_type) { :transactional_id }
      let(:acl1) do
        config = defaults.dup
        config[:resource_type] = :transactional_id
        config[:permission_type] = :allow
        described_class.new(**config)
      end

      let(:acl2) do
        config = defaults.dup
        config[:resource_type] = :transactional_id
        config[:permission_type] = :deny
        described_class.new(**config)
      end

      before do
        described_class.create(acl1)
        described_class.create(acl2)
      end

      it { expect(describing.size).to eq(2) }
      it { expect(describing.map(&:resource_type).uniq).to eq([:transactional_id]) }
      it { expect(describing.map(&:resource_name).uniq).to eq([resource_name]) }
    end
  end

  describe '#all' do
    subject(:all) { described_class.all }

    let(:permission_type) { :allow }

    before { described_class.create(acl) }

    it { expect { all }.not_to raise_error }
    it { expect(all).not_to be_empty }
    it { expect(all.map(&:resource_name)).to include(acl.resource_name) }

    context 'when listing all acls including transactional id' do
      let(:resource_type) { :transactional_id }
      let(:permission_type) { :allow }

      before { described_class.create(acl) }

      it { expect { all }.not_to raise_error }
      it { expect(all).not_to be_empty }
      it { expect(all.map(&:resource_name)).to include(acl.resource_name) }
      it { expect(all.map(&:resource_type)).to include(:transactional_id) }
    end
  end
end
