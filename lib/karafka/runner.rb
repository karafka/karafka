# frozen_string_literal: true

module Karafka
  # Class used to run the Karafka listeners in separate threads
  class Runner
    Worker = Struct.new(:pid, :parent_reader)

    def initialize
      @manager = App.config.internal.connection.manager
      @conductor = App.config.internal.connection.conductor
    end

    # Starts listening on all the listeners asynchronously and handles the jobs queue closing
    # after listeners are done with their work.
    def call
      workers_c =1

      process = Karafka::App.config.internal.process

        process.supervise

      if workers_c > 0
        workers = workers_c.times.map do
          parent_reader, child_writer = IO.pipe

          pid = fork do
            begin
              parent_reader.close

              process.supervise
              Karafka::Web.config.tracking.scheduler.async_call

              run_one
            rescue Exception => e
              # Allow the parent process to re-raise the exception after shutdown
              child_writer.binmode
              child_writer.write(Marshal.dump(e))
            ensure
              child_writer.close
            end
          end

          child_writer.close

          Worker.new(pid, parent_reader)
        end

        begin
          ready_readers = IO.select(workers.map(&:parent_reader)).first
          first_read = ready_readers.first.read
        rescue Interrupt
          first_read = ''
        end

        workers.map(&:pid).each do |pid|
          Karafka.logger.debug "=> Waiting for worker with pid #{pid} to exit"
          ::Process.waitpid(pid)
          Karafka.logger.debug "=> Worker with pid #{pid} shutdown"
        end

        exception_found = !first_read.empty?
        raise Marshal.load(first_read) if exception_found

        sleep(10)

      else
        run_one
      end
    # If anything crashes here, we need to raise the error and crush the runner because it means
    # that something terrible happened
    rescue StandardError => e
      Karafka.monitor.instrument(
        'error.occurred',
        caller: self,
        error: e,
        type: 'runner.call.error'
      )
      Karafka::App.stop!

      raise e
    end

    private


    def terminate_workers(workers)
      return if @terminating

      @terminating = true
      $stderr.puts "=> Terminating workers"

      ::Process.kill("TERM", *workers.map(&:pid))
    end

    def run_one
      # Despite possibility of having several independent listeners, we aim to have one queue for
      # jobs across and one workers poll for that
      jobs_queue = App.config.internal.processing.jobs_queue_class.new

      workers = Processing::WorkersBatch.new(jobs_queue)
      listeners = Connection::ListenersBatch.new(jobs_queue)

      # We mark it prior to delegating to the manager as manager will have to start at least one
      # connection to Kafka, hence running
      Karafka::App.run!

      # Register all the listeners so they can be started and managed
      @manager.register(listeners)

      workers.each(&:async_call)

      # We aggregate threads here for a supervised shutdown process
      Karafka::Server.workers = workers
      Karafka::Server.listeners = listeners
      Karafka::Server.jobs_queue = jobs_queue

      until @manager.done?
        @conductor.wait

        @manager.control
      end

      # We close the jobs queue only when no listener threads are working.
      # This ensures, that everything was closed prior to us not accepting anymore jobs and that
      # no more jobs will be enqueued. Since each listener waits for jobs to finish, once those
      # are done, we can close.
      jobs_queue.close

      # All the workers need to stop processing anything before we can stop the runner completely
      # This ensures that even async long-running jobs have time to finish before we are done
      # with everything. One thing worth keeping in mind though: It is the end user responsibility
      # to handle the shutdown detection in their long-running processes. Otherwise if timeout
      # is exceeded, there will be a forced shutdown.
      workers.each(&:join)
    end
  end
end
