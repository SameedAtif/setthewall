module Performance
  class WeeklyExport
    def self.call(week_ending: Date.current)
      new(week_ending: week_ending).call
    end

    def initialize(week_ending:)
      @week_ending = week_ending
      @week_start  = week_ending - 6.days
    end

    def call
      pieces = pieces_in_window
      summary = build_summary(pieces)

      md_path   = write_markdown(summary)
      json_path = write_json(summary)

      { markdown_path: md_path, json_path: json_path,
        piece_count: pieces.size, cycle_id: cycle_id }
    end

    private

    def cycle_id
      @cycle_id ||= "cycle_#{@week_ending.strftime('%Y%m%d')}_#{SecureRandom.hex(3)}"
    end

    def pieces_in_window
      PieceRecord.published
                 .trustworthy      # excludes dirty:* runs — analysis has to be reproducible
                 .where(published_at: @week_start.beginning_of_day..@week_ending.end_of_day)
                 .includes(:performance_snapshots, :human_gates)
    end

    def build_summary(pieces)
      {
        window: { start: @week_start.iso8601, end: @week_ending.iso8601 },
        cycle_id: cycle_id,
        piece_count: pieces.size,
        kb_versions_in_play: pieces.map(&:kb_version).uniq,
        pieces: pieces.map { |p| piece_summary(p) },
        aggregates: aggregate_by_axis(pieces),
        gate_patterns: gate_pattern_summary(pieces),
        anti_pattern_watch: anti_pattern_flags(pieces)
      }
    end

    def piece_summary(p)
      last = p.performance_snapshots.order(:captured_on).last
      first = p.performance_snapshots.order(:captured_on).first
      {
        piece_id: p.id,
        etsy_listing_id: p.etsy_listing_id,
        kb_version: p.kb_version,
        style_slug: p.style_spec_slug,
        scene_spec_id: p.scene_spec_id,
        axes: {
          mood: p.mood, content_type: p.content_type, color_role: p.color_role_confirmed,
          frame_material: p.frame_material_category, matting: p.matting_technique
        },
        listing: {
          title: p.listing_title, tags: p.listing_tags, category: p.listing_category
        },
        metrics: {
          views: last&.views.to_i,
          favorites: last&.favorites.to_i,
          orders: last&.orders.to_i,
          revenue: last&.revenue.to_f,
          conversion_rate: last&.conversion_rate&.round(4),
          days_live: (last&.captured_on && first&.captured_on) ?
                       (last.captured_on - first.captured_on).to_i + 1 : 0,
          top_search_terms: last&.search_terms.to_a.first(5)
        },
        gate_decisions: p.human_gates.closed.map { |g|
          { step_id: g.step_id, status: g.status, notes: g.notes.to_s[0, 200] }
        }
      }
    end

    # Aggregate metrics by each axis value. This is what lets Claude say
    # "pieces with color_role=color_burst got 2.3x more views than line_only in this window"
    # without having to reconstruct the join itself.
    def aggregate_by_axis(pieces)
      %i[mood content_type color_role frame_material].each_with_object({}) do |axis, agg|
        agg[axis] = pieces.group_by { |p| p.send(axis == :frame_material ? :frame_material_category : axis) }
                          .transform_values { |grp|
                            {
                              piece_count: grp.size,
                              avg_views: avg(grp, :views),
                              avg_favorites: avg(grp, :favorites),
                              avg_orders: avg(grp, :orders),
                              total_revenue: grp.sum { |p| p.performance_snapshots.order(:captured_on).last&.revenue.to_f }.round(2)
                            }
                          }
      end
    end

    def avg(pieces, metric_key)
      values = pieces.map { |p| p.performance_snapshots.order(:captured_on).last&.send(metric_key).to_i }
      return 0 if values.empty?
      (values.sum.to_f / values.size).round(2)
    end

    def gate_pattern_summary(pieces)
      pieces.flat_map(&:human_gates).flat_map { |g| g }.group_by(&:step_id)
            .transform_values { |gates|
              {
                total: gates.size,
                rejected: gates.count { |g| g.status == "rejected" },
                edited: gates.count { |g| g.status == "edited" },
                approved: gates.count { |g| g.status == "approved" }
              }
            }
    end

    def anti_pattern_flags(pieces)
      # Read the Etsy anti-patterns rule file and check whether any observed pattern in this
      # window looks like one Claude might otherwise "discover" and try to propose.
      anti = KnowledgeBase::RuleSet.load("etsy_antipatterns").rules
      flags = []
      # Example: renewal-chasing — check for pieces republished mid-window.
      # (Placeholder pattern; the actual detection depends on Etsy stats richness. Kept as an
      # explicit hook so the anti-pattern watch is visible in the export even if empty.)
      flags
    end

    def write_markdown(summary)
      path = Rails.root.join("tmp", "evolution", "#{cycle_id}_summary.md")
      path.dirname.mkpath
      path.write(markdown_render(summary))
      path.to_s
    end

    def write_json(summary)
      path = Rails.root.join("tmp", "evolution", "#{cycle_id}_data.json")
      path.dirname.mkpath
      path.write(JSON.pretty_generate(summary))
      path.to_s
    end

    def markdown_render(s)
      <<~MD
        # Weekly Performance Export — #{s[:window][:start]} to #{s[:window][:end]}

        Cycle ID: `#{s[:cycle_id]}`
        Pieces published this window: #{s[:piece_count]}
        Knowledge-base versions in play: #{s[:kb_versions_in_play].join(', ')}

        ## Per-piece summary

        #{s[:pieces].map { |p| piece_md(p) }.join("\n\n")}

        ## Aggregates by axis

        #{aggregates_md(s[:aggregates])}

        ## Gate patterns

        #{gate_patterns_md(s[:gate_patterns])}

        ## Anti-pattern watch

        #{s[:anti_pattern_watch].any? ? s[:anti_pattern_watch].to_yaml : '(no flags this window)'}
      MD
    end

    def piece_md(p)
      m = p[:metrics]
      <<~M
        ### Piece ##{p[:piece_id]} — `#{p[:etsy_listing_id]}`
        - Axes: #{p[:axes].to_json}
        - KB version: `#{p[:kb_version]}`
        - Views: #{m[:views]} / Favorites: #{m[:favorites]} / Orders: #{m[:orders]} / Conversion: #{m[:conversion_rate]}
        - Days live: #{m[:days_live]}
        - Top search terms: #{m[:top_search_terms].join(', ')}
      M
    end

    def aggregates_md(agg)
      agg.map { |axis, groups|
        rows = groups.map { |val, m|
          "  - `#{val}`: #{m[:piece_count]} pieces, avg views #{m[:avg_views]}, avg orders #{m[:avg_orders]}, total revenue $#{m[:total_revenue]}"
        }.join("\n")
        "**By #{axis}**\n#{rows}"
      }.join("\n\n")
    end

    def gate_patterns_md(patterns)
      patterns.map { |step, counts|
        "- **#{step}**: #{counts[:total]} total → approved #{counts[:approved]}, edited #{counts[:edited]}, rejected #{counts[:rejected]}"
      }.join("\n")
    end
  end
end
