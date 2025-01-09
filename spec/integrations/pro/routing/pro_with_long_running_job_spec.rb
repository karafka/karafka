# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# I should be able to define a topic consumption with long-running job indication
# It should not impact other jobs and the default should not be lrj

setup_karafka

draw_routes(create_topics: false) do
  topic DT.topics[0] do
    consumer Class.new(Karafka::BaseConsumer)
    long_running_job true
  end

  topic DT.topics[1] do
    consumer Class.new(Karafka::BaseConsumer)
    long_running_job false
  end

  topic DT.topics[2] do
    consumer Class.new(Karafka::BaseConsumer)
    long_running_job false
  end
end

assert Karafka::App.routes.first.topics[0].long_running_job?
assert_equal false, Karafka::App.routes.first.topics[1].long_running_job?
assert_equal false, Karafka::App.routes.first.topics[2].long_running_job?
