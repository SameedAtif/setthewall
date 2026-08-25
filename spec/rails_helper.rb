require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"

# Load every spec/support/*.rb helper (stubbing, fixtures, pipeline helpers).
Rails.root.glob("spec/support/**/*.rb").sort.each { |f| require f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join("spec/fixtures")]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
  config.include SingletonStubbing
  config.include LlmStubs
  config.include AdapterStubs
  config.include PipelineHelpers

  # Remove any knowledge-base files a spec wrote (see PipelineHelpers#track_kb_file).
  config.after(:each) do
    (@tracked_kb_files || []).each { |f| File.delete(f) rescue nil }
    @tracked_kb_files = []
  end
end
