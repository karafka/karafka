# Application worker from which all workers should inherit
# You can rename it if it would conflict with your current code base (in case you're integrating
# Karafka with other frameworks). Karafka will use first direct descendant of Karafka::BaseWorker
# to build worker classes
class ApplicationWorker < Karafka::BaseWorker
  # You can disable WorkerGlass components if you want to
  prepend WorkerGlass::Timeout
  prepend WorkerGlass::Reentrancy

  # If you remove WorkerGlass::Timeout, this line will be useless as well
  self.timeout = 60
end
