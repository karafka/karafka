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
  subject(:listener) { described_class.new }

  let(:event) { instance_double(Karafka::Core::Monitoring::Event) }
  let(:dispatcher) { Karafka::Pro::RecurringTasks::Dispatcher }

  describe '#on_recurring_tasks_task_executed' do
    before { allow(dispatcher).to receive(:log) }

    it 'logs the event using Dispatcher' do
      listener.on_recurring_tasks_task_executed(event)

      expect(dispatcher).to have_received(:log).with(event)
    end
  end

  describe '#on_error_occurred' do
    before { allow(dispatcher).to receive(:log) }

    context 'when event type is recurring_tasks.task.execute.error' do
      let(:event) { { type: 'recurring_tasks.task.execute.error', other_data: 'data' } }

      it 'logs the event using Dispatcher' do
        listener.on_error_occurred(event)

        expect(dispatcher).to have_received(:log).with(event)
      end
    end

    context 'when event type is not recurring_tasks.task.execute.error' do
      let(:event) { { type: 'some_other_error', other_data: 'data' } }

      it 'does not log the event' do
        listener.on_error_occurred(event)

        expect(dispatcher).not_to have_received(:log)
      end
    end
  end
end
