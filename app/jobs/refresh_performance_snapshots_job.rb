class RefreshPerformanceSnapshotsJob < ApplicationJob
  queue_as :default

  def perform
    Performance::EtsyStatsFetcher.call(date: Date.current)
  end
end
