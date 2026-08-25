module Performance
  class EtsyStatsFetcher
    # For each published PieceRecord, fetch current-day metrics and upsert a snapshot for today.
    # Idempotent per (piece_record_id, captured_on) — safe to re-run the same day.
    def self.call(date: Date.current)
      PieceRecord.published.trustworthy.find_each do |piece|
        fetch_and_upsert(piece, date)
      end
    end

    def self.fetch_and_upsert(piece, date)
      client = Etsy::Adapter.build
      return if client.name == "manual"    # manual adapter has no fetch; skip silently

      metrics = client.fetch_listing_stats(listing_id: piece.etsy_listing_id, date: date)

      PerformanceSnapshot.find_or_initialize_by(
        piece_record_id: piece.id, captured_on: date
      ).tap do |s|
        s.views       = metrics.fetch(:views, 0)
        s.favorites   = metrics.fetch(:favorites, 0)
        s.orders      = metrics.fetch(:orders, 0)
        s.revenue     = metrics.fetch(:revenue, 0)
        s.search_terms = metrics.fetch(:search_terms, [])
        s.raw         = metrics
        s.save!
      end
    rescue Etsy::ApiError => e
      Rails.logger.warn "EtsyStatsFetcher: piece #{piece.id} failed — #{e.message}"
    end
  end
end
