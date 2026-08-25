require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Namespace modules for the pipeline's custom app/ autoload roots. Rails treats
# every app/<dir> as a top-level root (namespace Object), so `app/knowledge_base/
# rule_set.rb` would otherwise be expected to define a top-level `RuleSet`. These
# modules (plus the initializer below) pin the directories to their namespaces.
module KnowledgeBase; end
module Steps; end
module Workflow; end
module Tools; end

module Setthewall
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Pin the pipeline's first-level app/ directories to their namespaces.
    initializer :setup_pipeline_autoload_namespaces, before: :setup_main_autoloader do
      autoloader = Rails.autoloaders.main
      autoloader.push_dir(Rails.root.join("app/knowledge_base"), namespace: KnowledgeBase)
      autoloader.push_dir(Rails.root.join("app/steps"), namespace: Steps)
      autoloader.push_dir(Rails.root.join("app/workflow"), namespace: Workflow)
      autoloader.push_dir(Rails.root.join("app/tools"), namespace: Tools)
    end

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
