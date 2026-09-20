module Workflow
  # Pushes notebook updates over Turbo Streams. Callers broadcast to the run; the browser
  # subscribes with `turbo_stream_from run`.
  #
  # Broadcasts never break execution, and a failure never leaves the browser silently stale:
  # if rendering/publishing a cell, header or dossier update raises, the clients are told to
  # refresh (Turbo's `refresh` stream action) so the page self-heals instead of waiting for a
  # manual reload. Log-line failures only log, since they are frequent and low-stakes.
  class NotebookBroadcaster
    class << self
      def cell(run, step)
        publish(run) do
          Turbo::StreamsChannel.broadcast_replace_to(
            run,
            target: "run_step_#{step.id}",
            partial: "run_steps/cell",
            locals: { run: run, step: step, index: step.position.to_i + 1 }
          )
        end
      end

      # A newly materialized cell has no existing target to replace, so append it to the cell list.
      def append_cell(run, step)
        publish(run) do
          Turbo::StreamsChannel.broadcast_append_to(
            run,
            target: "notebook_cells",
            partial: "run_steps/cell",
            locals: { run: run, step: step, index: step.position.to_i + 1 }
          )
        end
      end

      def header(run)
        publish(run) do
          Turbo::StreamsChannel.broadcast_replace_to(
            run, target: "run_header", partial: "runs/header", locals: { run: run }
          )
        end
      end

      def dossier(run)
        publish(run) do
          Turbo::StreamsChannel.broadcast_replace_to(
            run, target: "dossier", partial: "runs/dossier", locals: { run: run }
          )
        end
      end

      def log(run, step, entry)
        # A stuck log line is not worth reloading the page for; just record the failure.
        publish(run, refresh: false) do
          Turbo::StreamsChannel.broadcast_append_to(
            run, target: "run_step_#{step.id}_log",
                 partial: "run_steps/log_line", locals: { entry: entry }
          )
        end
      end

      private

      def publish(run, refresh: true)
        yield
      rescue StandardError => e
        Rails.logger.error(
          "[NotebookBroadcaster] broadcast failed: #{e.class}: #{e.message}\n" \
          "#{Array(e.backtrace).first(5).join("\n")}"
        )
        refresh_clients(run) if refresh
        nil
      end

      def refresh_clients(run)
        Turbo::StreamsChannel.broadcast_refresh_to(run)
      rescue StandardError => e
        Rails.logger.error("[NotebookBroadcaster] refresh broadcast failed: #{e.class}: #{e.message}")
        nil
      end
    end
  end
end
