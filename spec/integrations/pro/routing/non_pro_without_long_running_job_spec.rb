# frozen_string_literal: true

# When running non-pro, LRJ should not be available

setup_karafka(pro: false)

not_found = false

begin
  draw_routes do
    consumer_group DT.consumer_group do
      topic DT.topics[0] do
        consumer Class.new
        long_running_job true
      end
    end
  end
rescue NoMethodError
  not_found = true
end

assert not_found
