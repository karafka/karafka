# frozen_string_literal: true

# Karafka should use different partitioners and karafka options for jobs and not mutate in between

setup_karafka
setup_active_job

class Default < ActiveJob::Base
end

class JobA < ActiveJob::Base
  karafka_options(
    dispatch_method: :produce_sync,
    dispatch_many_method: :produce_many_sync
  )

  def perform
  end
end

class JobB < ActiveJob::Base
  karafka_options(
    dispatch_method: :produce_async
  )

  def perform
  end
end

class JobC < JobA
  karafka_options(
    dispatch_method: :produce_async
  )
end

assert Default.karafka_options != JobA
assert Default.karafka_options != JobB
assert Default.karafka_options != JobC
assert JobA.karafka_options != JobB.karafka_options
assert JobA.karafka_options != JobC.karafka_options
assert JobA.karafka_options[:dispatch_method] != JobB.karafka_options[:dispatch_method]
