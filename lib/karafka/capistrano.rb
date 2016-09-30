# Load Capistrano tasks only if Capistrano is loaded
load File.expand_path('../capistrano/karafka.cap', __FILE__) if defined?(Capistrano)
