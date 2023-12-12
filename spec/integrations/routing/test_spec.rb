# frozen_string_literal: true

setup_karafka
setup_active_job

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.topic] << message.offset
    end
  end
end

draw_routes(create_topics: false) do
  consumer_group :oem do
    active_job_topic :jobs do
      dead_letter_queue(
        topic: 'dead_jobs',
        max_retries: 1
      )
    end

    topic :dead_jobs do
      consumer Consumer
    end

    topic :dead_messages do
      consumer Consumer
    end

    topic :user_deletion do
      consumer Consumer
      dead_letter_queue(
        topic: 'dead_messages',
        max_retries: 2
      )
    end
  end
end

start_karafka_and_wait_until do
end
