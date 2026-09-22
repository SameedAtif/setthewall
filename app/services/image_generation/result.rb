module ImageGeneration
  # Returned by every adapter's `generate`. Kept in its own file so it is autoloadable on its own
  # (referencing it before `Adapter` otherwise raises NameError under Zeitwerk).
  Result = Struct.new(:urls, :provider, :model, :estimated_cost_usd, :raw_response, keyword_init: true)
end
