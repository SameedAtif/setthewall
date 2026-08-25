module Steps
  module Phase2
    class WeightBalance < Steps::Base
      step id: "P2_5", mechanism: :lookup, ownership: "[AGENT-READY]"

      def perform
        rule = rules("weight_balance").fetch("check", piece.furniture_weight)

        # A real weight-scoring model is out of scope for MVP. The check here is:
        # dark furniture + dark heavy frame ("ornate_carved" or metal with "black" finish + no mat)
        # → likely fails; flag for human. Light furniture + anything → pass.
        art_reads_heavy = %w[ornate_carved].include?(piece.frame_material_category) ||
                          piece.mat_intensity.to_s.include?("dark")

        pass = case piece.furniture_weight
               when "dark"  then !art_reads_heavy
               when "light" then true
               end

        piece.update!(weight_balance_pass: pass)

        if pass
          ok({ furniture_weight: piece.furniture_weight, art_reads_heavy: art_reads_heavy })
        else
          needs_human(
            "Weight balance fails: dark furniture requires art LIGHTER than the furniture, but " \
            "this piece's frame/material reads heavy (#{piece.frame_material_category}, " \
            "mat=#{piece.mat_intensity}). Change frame or accept the risk.",
            { furniture_weight: piece.furniture_weight, frame_reads_heavy: art_reads_heavy }
          )
        end
      end
    end
  end
end
