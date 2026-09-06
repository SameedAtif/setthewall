# SolidQueue routes its log to Rails.logger (log/development.log) by default, which makes
# `bin/jobs` look like it's doing nothing while a job runs. Mirror Rails.logger to STDOUT in
# development so the worker terminal shows job, search, and step progress as it happens.
if Rails.env.development?
  stdout = ActiveSupport::Logger.new($stdout)
  stdout.formatter = ActiveSupport::Logger::SimpleFormatter.new

  Rails.logger.broadcast_to(stdout)
end
