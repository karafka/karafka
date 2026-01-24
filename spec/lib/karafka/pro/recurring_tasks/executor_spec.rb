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
  subject(:executor) { described_class.new }

  let(:schedule) { Karafka::Pro::RecurringTasks::Schedule.new(version: '1.0.0') }
  let(:task) { Karafka::Pro::RecurringTasks::Task.new(id: 'task1', cron: '* * * * *') }
  let(:dispatcher) { Karafka::Pro::RecurringTasks::Dispatcher.new }
  let(:matcher) { Karafka::Pro::RecurringTasks::Matcher.new }
  let(:command_name) { 'disable' }
  let(:command_hash) { { command: { name: command_name }, task: { id: :task1 } } }
  let(:schedule_hash) do
    {
      schedule_version: '1.0.0',
      tasks: {
        task1: {
          id: :task1,
          previous_time: Time.now.to_i,
          enabled: true
        }
      }
    }
  end

  before do
    allow(Karafka::Pro::RecurringTasks).to receive(:schedule).and_return(schedule)
    allow(schedule).to receive(:each).and_yield(task)
    allow(executor).to receive(:snapshot)
    allow(matcher).to receive(:matches?).and_return(true)
    allow(task).to receive(:call)
    allow(task).to receive(:disable)
    allow(task).to receive(:changed?).and_return(false)
    executor.instance_variable_set(:@matcher, matcher)
  end

  describe '#replaying?' do
    it 'returns true when in replaying phase' do
      expect(executor.replaying?).to be true
    end

    it 'returns false after replay is completed' do
      executor.replay
      expect(executor.replaying?).to be false
    end
  end

  describe '#incompatible?' do
    it 'returns false initially' do
      expect(executor.incompatible?).to be false
    end

    it 'returns true if schedule version is incompatible' do
      executor.update_state(schedule_hash.merge(schedule_version: '2.0.0'))
      executor.replay
      expect(executor.incompatible?).to be true
    end
  end

  describe '#apply_command' do
    context 'when command is supported' do
      it 'applies the command to matching tasks' do
        executor.apply_command(command_hash)
        expect(task).to have_received(command_name)
      end
    end

    context 'when command is not supported' do
      let(:command_name) { 'unsupported_command' }

      it 'raises an error' do
        expect { executor.apply_command(command_hash) }
          .to raise_error(Karafka::Errors::UnsupportedCaseError)
      end
    end
  end

  describe '#update_state' do
    it 'updates the catchup schedule' do
      executor.update_state(schedule_hash)
      expect(executor.instance_variable_get(:@catchup_schedule)).to eq(schedule_hash)
    end
  end

  describe '#replay' do
    context 'when replaying is already done' do
      before do
        allow(task).to receive(:snapshot)
        executor.replay
      end

      it 'does not replay again' do
        executor.replay

        expect(executor).to have_received(:snapshot).once
      end
    end

    context 'when there is no catchup data' do
      it 'snapshots immediately' do
        executor.replay
        expect(executor).to have_received(:snapshot)
      end
    end

    context 'when schedule version is incompatible' do
      before do
        executor.update_state(schedule_hash.merge(schedule_version: '2.0.0'))
      end

      it 'marks the schedule as incompatible' do
        executor.replay
        expect(executor.incompatible?).to be true
      end
    end

    context 'when there is catchup data' do
      before do
        executor.update_state(schedule_hash)
        allow(task).to receive(:previous_time=)
        allow(task).to receive(:enable)
      end

      it 'updates the task state based on the catchup schedule' do
        time = Time.at(schedule_hash[:tasks][:task1][:previous_time])
        executor.replay
        expect(task).to have_received(:previous_time=).with(time)
        expect(task).to have_received(:enable)
      end

      it 'applies catchup commands' do
        executor.instance_variable_set(:@catchup_commands, [command_hash])
        executor.replay
        expect(task).to have_received(command_name)
      end

      it 'snapshots after replay' do
        executor.replay
        expect(executor).to have_received(:snapshot)
      end
    end
  end

  describe '#call' do
    context 'when no tasks are changed or executable' do
      it 'does not snapshot' do
        executor.call
        expect(executor).not_to have_received(:snapshot)
      end
    end

    context 'when a task is changed' do
      before do
        allow(task).to receive(:changed?).and_return(true)
      end

      it 'snapshots after execution' do
        executor.call
        expect(executor).to have_received(:snapshot)
      end
    end

    context 'when a task is executable' do
      before do
        allow(task).to receive(:call?).and_return(true)
        allow(task).to receive(:snapshot)
      end

      it 'executes the task and snapshots' do
        executor.call
        expect(task).to have_received(:call)
        expect(executor).to have_received(:snapshot)
      end
    end
  end
end
