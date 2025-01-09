# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka should use different partitioners and karafka options for jobs and not mutate in between

setup_karafka
setup_active_job

class Default < ActiveJob::Base
end

class JobA < ActiveJob::Base
  karafka_options(
    partitioner: ->(_) { 'a' },
    dispatch_method: :produce_sync
  )

  def perform; end
end

class JobB < ActiveJob::Base
  karafka_options(
    partitioner: ->(_) { 'b' },
    dispatch_method: :produce_sync
  )

  def perform; end
end

class JobC < JobA
  # This should replace only dispatch method and use parent partitioner
  karafka_options(
    dispatch_method: :produce_async
  )
end

assert_equal Default.karafka_options[:dispatch_method], nil
assert_equal JobA.karafka_options[:dispatch_method], :produce_sync
assert_equal JobB.karafka_options[:dispatch_method], :produce_sync
assert_equal JobC.karafka_options[:dispatch_method], :produce_async

assert Default.karafka_options != JobA
assert Default.karafka_options != JobB
assert Default.karafka_options != JobC
assert JobA.karafka_options != JobB.karafka_options
assert JobA.karafka_options != JobC.karafka_options
assert_equal JobA.karafka_options[:partitioner], JobC.karafka_options[:partitioner]
