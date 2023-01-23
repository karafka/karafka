# frozen_string_literal: true

RSpec.describe_current do
  subject(:selected_strategy) { described_class.new.find(topic) }

  let(:topic) { build(:routing_topic) }

  context 'when no features enabled' do
    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Default) }
  end

  context 'when manual offset management is on' do
    before { topic.manual_offset_management(true) }

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Mom) }
  end

  context 'when virtual partitions are on' do
    before { topic.virtual_partitions(partitioner: true) }

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Vp) }
  end

  context 'when lrj is enabled with vp' do
    before do
      topic.long_running_job(true)
      topic.virtual_partitions(partitioner: true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::LrjVp) }
  end

  context 'when lrj is enabled with mom' do
    before do
      topic.long_running_job(true)
      topic.manual_offset_management(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::LrjMom) }
  end

  context 'when lrj is enabled' do
    before { topic.long_running_job(true) }

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Lrj) }
  end

  context 'when aj is enabled with mom and vp' do
    before do
      topic.active_job(true)
      topic.manual_offset_management(true)
      topic.virtual_partitions(partitioner: true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::AjMomVp) }
  end

  context 'when aj is enabled with mom' do
    before do
      topic.active_job(true)
      topic.manual_offset_management(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::AjMom) }
  end

  context 'when aj is enabled with lrj, mom and vp' do
    before do
      topic.active_job(true)
      topic.manual_offset_management(true)
      topic.long_running_job(true)
      topic.virtual_partitions(partitioner: true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::AjLrjMomVp) }
  end

  context 'when aj is enabled with lrj and mom' do
    before do
      topic.active_job(true)
      topic.manual_offset_management(true)
      topic.long_running_job(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::AjLrjMom) }
  end

  context 'when we enable not supported combination' do
    before do
      topic.active_job(true)
      topic.long_running_job(true)
    end

    it { expect { selected_strategy }.to raise_error(Karafka::Errors::StrategyNotFoundError) }
  end

  context 'when dlq is enabled' do
    before { topic.dead_letter_queue(topic: 'test') }

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::Dlq) }
  end

  context 'when dlq with vp is enabled' do
    before do
      topic.dead_letter_queue(topic: 'test')
      topic.virtual_partitions(partitioner: true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::DlqVp) }
  end

  context 'when dlq with mom is enabled' do
    before do
      topic.dead_letter_queue(topic: 'test')
      topic.manual_offset_management(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::DlqMom) }
  end

  context 'when dlq, mom and lrj is enabled' do
    before do
      topic.dead_letter_queue(topic: 'test')
      topic.manual_offset_management(true)
      topic.long_running_job(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::DlqLrjMom) }
  end

  context 'when aj, dlq and mom is enabled' do
    before do
      topic.dead_letter_queue(topic: 'test')
      topic.manual_offset_management(true)
      topic.active_job(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::AjDlqMom) }
  end

  context 'when aj, dlq, mom and vp is enabled' do
    before do
      topic.virtual_partitions(partitioner: true)
      topic.dead_letter_queue(topic: 'test')
      topic.manual_offset_management(true)
      topic.active_job(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::AjDlqMomVp) }
  end

  context 'when aj, dlq, mom and lrj is enabled' do
    before do
      topic.dead_letter_queue(topic: 'test')
      topic.manual_offset_management(true)
      topic.long_running_job(true)
      topic.active_job(true)
    end

    it { expect(selected_strategy).to eq(Karafka::Pro::Processing::Strategies::AjDlqLrjMom) }
  end
end
