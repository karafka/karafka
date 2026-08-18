# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# The filtering strategy resolves `filter.action` in a `case` whose `else` raises
# `Karafka::Errors::UnsupportedCaseError` for any action outside :skip/:seek/:pause. A missing comma
# (`raise Klass value` instead of `raise Klass, value`) made Ruby parse that as `raise Klass(value)`,
# raising NoMethodError with a confusing message instead. FiltersApplier#action only ever returns the
# three supported actions, so we force an unsupported one here to reach that guard and prove it now
# raises the intended UnsupportedCaseError.

setup_karafka(allow_errors: true)

# Forces the aggregated post-filtering action to an unsupported value so the strategy hits its `else`
module UnsupportedAction
  def action
    :unsupported
  end
end

Karafka::Pro::Processing::ConsumerGroups::Coordinators::FiltersApplier.prepend(UnsupportedAction)

# Minimal filter so the filtering strategy is active for this topic
class NoopFilter < Karafka::Pro::Processing::ConsumerGroups::Filters::Base
  def apply!(messages)
    @applied = false
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:consumed] << message.offset }
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    filter(->(*) { NoopFilter.new })
  end
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:error] = event[:error]
end

produce_many(DT.topic, DT.uuids(1))

start_karafka_and_wait_until do
  DT.key?(:error)
end

assert DT[:error].is_a?(Karafka::Errors::UnsupportedCaseError), DT[:error].class
