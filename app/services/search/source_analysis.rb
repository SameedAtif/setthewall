module Search
  # Derives source/seller independence from result URLs, so a step's reported source counts can be
  # recomputed in code rather than trusted from the model's self-report (module 09 §5.4 principle).
  module SourceAnalysis
    module_function

    # Distinct normalized hosts across the given URLs. Two URLs on one host are one source.
    def distinct_hosts(urls)
      Array(urls).filter_map { |u| normalize_host(host_of(u)) }.uniq
    end

    def host_of(url)
      URI.parse(url.to_s).host.presence
    rescue URI::Error
      nil
    end

    # Strips www/m/mobile subdomains so "www.etsy.com", "m.etsy.com" and "etsy.com" count once.
    def normalize_host(host)
      return nil if host.blank?

      host.to_s.sub(/\A(www|m|mobile)\./, "")
    end
  end
end
