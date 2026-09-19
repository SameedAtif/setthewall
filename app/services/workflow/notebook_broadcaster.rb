module Workflow
  # Pushes notebook updates over Turbo Streams. Callers broadcast to the run; the browser
  # subscribes with `turbo_stream_from run`. Rendering/publish failures never break execution.
  class NotebookBroadcaster
    def self.cell(run, step)
      Turbo::StreamsChannel.broadcast_replace_to(
        run,
        target: "run_step_#{step.id}",
        partial: "run_steps/cell",
        locals: { run: run, step: step, index: step.position.to_i + 1 }
      )
    rescue StandardError => e
      Rails.logger.warn("[NotebookBroadcaster] cell broadcast failed: #{e.message}")
    end

    # A newly materialized cell has no existing target to replace, so append it to the cell list.
    def self.append_cell(run, step)
      Turbo::StreamsChannel.broadcast_append_to(
        run,
        target: "notebook_cells",
        partial: "run_steps/cell",
        locals: { run: run, step: step, index: step.position.to_i + 1 }
      )
    rescue StandardError => e
      Rails.logger.warn("[NotebookBroadcaster] append_cell failed: #{e.message}")
    end

    def self.header(run)
      Turbo::StreamsChannel.broadcast_replace_to(
        run, target: "run_header", partial: "runs/header", locals: { run: run }
      )
    rescue StandardError => e
      Rails.logger.warn("[NotebookBroadcaster] header broadcast failed: #{e.message}")
    end

    def self.dossier(run)
      Turbo::StreamsChannel.broadcast_replace_to(
        run, target: "dossier", partial: "runs/dossier", locals: { run: run }
      )
    rescue StandardError => e
      Rails.logger.warn("[NotebookBroadcaster] dossier broadcast failed: #{e.message}")
    end

    def self.log(run, step, entry)
      Turbo::StreamsChannel.broadcast_append_to(
        run, target: "run_step_#{step.id}_log",
             partial: "run_steps/log_line", locals: { entry: entry }
      )
    rescue StandardError => e
      Rails.logger.warn("[NotebookBroadcaster] log broadcast failed: #{e.message}")
    end
  end
end
