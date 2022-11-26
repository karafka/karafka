# frozen_string_literal: true

# When running non-pro, VP should not be available

setup_karafka(pro: false)

not_found = false

begin
  draw_routes do
    consumer_group DT.consumer_group do
      topic DT.topics[0] do
        consumer Class.new
        virtual_partitions(
          partitioner: ->(msg) { msg.raw_payload }
        )
      end
    end
  end
rescue NoMethodError
  not_found = true
end

assert not_found
