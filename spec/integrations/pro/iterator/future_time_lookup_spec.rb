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

# When we want to get something from the future and there is nothing, we should just stop

setup_karafka

draw_routes do
  topic DT.topic do
    active false
  end
end

produce(DT.topic, "1")

iterator = Karafka::Pro::Iterator.new(
  { DT.topic => { 0 => Time.now + 60 } }
)

# No checks needed as in case we would get something older, it will raise
iterator.each { raise }
