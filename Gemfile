source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.4"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

# --- Pipeline (module 00) ---
# LLM provider abstraction. ruby_llm 1.16.x is the latest release; it depends on
# ruby_llm-schema ~> 0 (the pre-schematist envelope format), so pin the schema gem to
# 0.4.x to keep bundler from pulling ruby_llm-schema 1.0.0 (a forwarding shim to
# `schematist` whose `to_json_schema` returns a Draft 2020-12 document that ruby_llm's
# `with_schema` does not consume).
gem "ruby_llm"
gem "ruby_llm-schema", "~> 0.4"

# Local env var loading
gem "dotenv-rails", groups: [:development, :test]

# HTTP for the image-generation and Etsy APIs
gem "faraday"

# Image compositing (Step 6) — deterministic, not an LLM
gem "ruby-vips"

# Render the dossier markdown in the notebook UI (pure Ruby, no native extension)
gem "kramdown"
gem "kramdown-parser-gfm"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Audit Gemfile.lock for known-vulnerable gems [https://github.com/rubysec/bundler-audit]
  gem "bundler-audit", require: false

  # Behavior-driven testing [https://github.com/rspec/rspec-rails]
  gem "rspec-rails", "~> 7.0"

  # Test data factories [https://github.com/thoughtbot/factory_bot_rails]
  gem "factory_bot_rails", "~> 6.4"
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Lint ERB templates [https://github.com/Shopify/erb-lint]
  gem "erb_lint", require: false
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"

  # Code coverage for the test suite
  gem "simplecov", require: false
end
