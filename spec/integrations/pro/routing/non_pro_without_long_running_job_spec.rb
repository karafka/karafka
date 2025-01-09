# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# When running non-pro, LRJ should not be available

setup_karafka(pro: false)

not_found = false

begin
  draw_routes(create_topics: false) do
    topic DT.topics[0] do
      consumer Class.new
      long_running_job true
    end
  end
rescue NoMethodError
  not_found = true
end

assert not_found
