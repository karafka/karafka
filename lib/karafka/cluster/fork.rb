# frozen_string_literal: true

module Karafka
  module Cluster
    class Fork
      attr_reader :pid
      attr_reader :parent_reader

      def initialize(pid, parent_reader)
        @pid = pid
        @parent_reader = parent_reader
      end

      def alive?
        ::Process.waitpid(@pid, Process::WNOHANG).nil?
      end

      def stop
        begin
          ::Process.kill("TERM", @pid)
        rescue Errno::ESRCH
        end
      end

      def silence
        begin
          ::Process.kill("TSTP", @pid)
        rescue Errno::ESRCH
        end
      end

      def terminate
        begin
          ::Process.kill("KILL", @pid)
        rescue Errno::ESRCH
        end
      end
    end
  end
end
