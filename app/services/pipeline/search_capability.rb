module Pipeline
  module SearchCapability
    # True only if the installed RubyLLM actually exposes with_server_tools on Chat.
    # Checked at runtime, not assumed from documentation, since this has been reported as
    # inconsistent across recent RubyLLM versions.
    def self.server_side_web_search_available?
      RubyLLM::Chat.instance_methods.include?(:with_server_tools)
    rescue NameError, StandardError
      false
    end
  end
end
