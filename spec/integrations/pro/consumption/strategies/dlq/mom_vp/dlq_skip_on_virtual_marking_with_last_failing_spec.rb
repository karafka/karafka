# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When running MoM + VP and marking on each, when we crash on last message out of all,
# previous should be handled and we should restart and then dispatch only this single one.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 5
  config.max_messages = 100
end

class Consumer < Karafka::BaseConsumer
  def consume
    collapsed?

    track

    trigger
  end
end
