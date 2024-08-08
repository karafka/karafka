# frozen_string_literal: true

RSpec.describe_current do
  subject(:topic) do
    build(:routing_topic).tap do |topic|
      topic.singleton_class.prepend described_class
    end
  end

  describe '#periodic_job' do
    context 'when we use periodic_job without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.periodic_job.active?).to eq(false)
        expect(topic.periodic_job.interval).to eq(5_000)
      end
    end

    context 'when used via the periodic alias without any arguments' do
      it 'expect to initialize with defaults' do
        expect(topic.periodic.active?).to eq(false)
        expect(topic.periodic_job.interval).to eq(5_000)
      end
    end

    context 'when we use periodic_job with active status' do
      it 'expect to use proper active status' do
        topic.periodic(true)
        expect(topic.periodic_job.active?).to eq(true)
      end
    end

    context "with long running job unset" do
      it "should default to false if during_pause unset" do
        topic.periodic(true)
        expect(topic.periodic_job.active?).to eq(true)
        expect(topic.periodic_job.materialized).to eq(false)
        expect(topic.periodic_job.during_pause).to eq(nil)
      end

      it "should default to true if during_pause is false" do
        topic.periodic(true, during_pause: false)
        expect(topic.periodic_job.active?).to eq(true)
        expect(topic.periodic_job.materialized).to eq(true)
        expect(topic.periodic_job.during_pause).to eq(false)
      end

      it "should be true if during_pause is true" do
        topic.periodic(true, during_pause: true)
        expect(topic.periodic_job.active?).to eq(true)
        expect(topic.periodic_job.materialized).to eq(true)
        expect(topic.periodic_job.during_pause).to eq(true)
      end
    end

    context "with long running job inactive" do
      before(:each) { topic.long_running_job(false) }

      it "should default to false if during_pause unset" do
        topic.periodic(true)
        expect(topic.periodic_job.active?).to eq(true)
        expect(topic.periodic_job.materialized).to eq(true)
        expect(topic.periodic_job.during_pause).to eq(true)
      end

      it "should default to true if during_pause is false" do
        topic.periodic(true, during_pause: false)
        expect(topic.periodic_job.active?).to eq(true)
        expect(topic.periodic_job.materialized).to eq(true)
        expect(topic.periodic_job.during_pause).to eq(false)
      end

      it "should be true if during_pause is true" do
        topic.periodic(true, during_pause: true)
        expect(topic.periodic_job.active?).to eq(true)
        expect(topic.periodic_job.materialized).to eq(true)
        expect(topic.periodic_job.during_pause).to eq(true)
      end
    end

    context "with long running job active" do
      before(:each) { topic.long_running_job(true) }

      it "should default to false if during_pause unset" do
        topic.periodic(true)
        expect(topic.periodic_job.active?).to eq(true)
        expect(topic.periodic_job.materialized).to eq(true)
        expect(topic.periodic_job.during_pause).to eq(false)
      end

      it "should default to true if during_pause is false" do
        topic.periodic(true, during_pause: false)
        expect(topic.periodic_job.active?).to eq(true)
        expect(topic.periodic_job.materialized).to eq(true)
        expect(topic.periodic_job.during_pause).to eq(false)
      end

      it "should be true if during_pause is true" do
        topic.periodic(true, during_pause: true)
        expect(topic.periodic_job.active?).to eq(true)
        expect(topic.periodic_job.materialized).to eq(true)
        expect(topic.periodic_job.during_pause).to eq(true)
      end
    end

    context 'when we use periodic_job multiple times with different values' do
      it 'expect to use proper active status' do
        topic.periodic(true)
        topic.periodic(false)
        expect(topic.periodic_job.active?).to eq(false)
        expect(topic.periodic_job.interval).to eq(5_000)
      end
    end

    context 'when initialized only with interval' do
      it 'expect to use proper active status and interval' do
        topic.periodic(interval: 2_500)
        expect(topic.periodic_job.active?).to eq(true)
        expect(topic.periodic_job.interval).to eq(2_500)
      end
    end
  end

  describe '#periodic_job?' do
    context 'when active' do
      before { topic.periodic(true) }

      it { expect(topic.periodic_job?).to eq(true) }
    end

    context 'when not active' do
      before { topic.periodic(false) }

      it { expect(topic.periodic_job?).to eq(false) }
    end
  end

  describe '#to_h' do
    it { expect(topic.to_h[:periodic_job]).to eq(topic.periodic_job.to_h) }
  end
end
