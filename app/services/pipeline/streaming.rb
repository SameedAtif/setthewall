require "timeout"

module Pipeline
  # Runs a streamed RubyLLM call with a no-progress watchdog.
  #
  # Streaming keeps the connection alive during long "thinking" generations, but a *stalled*
  # connection sends no chunks at all and the blocking socket read would wait forever. This wrapper
  # aborts and retries when no chunk arrives within `stall_seconds`, and after `attempts` raises
  # Stalled so the step fails fast instead of hanging. A progressing generation of any length is
  # unaffected (each chunk resets the stall timer).
  module Streaming
    class Stalled < StandardError; end

    DEFAULT_STALL_SECONDS = 120
    DEFAULT_ATTEMPTS = 2

    module_function

    def ask(chat, prompt, stall_seconds: nil, attempts: nil)
      stall = Float(stall_seconds || ENV.fetch("LLM_STREAM_STALL_SECONDS", DEFAULT_STALL_SECONDS))
      tries = (attempts || ENV.fetch("LLM_STREAM_ATTEMPTS", DEFAULT_ATTEMPTS)).to_i
      last_error = nil

      tries.times do |index|
        snapshot = chat.messages.dup
        begin
          return stream_once(chat, prompt, stall)
        rescue Stalled => e
          last_error = e
          restore_messages(chat, snapshot)
          Rails.logger.warn("[Pipeline::Streaming] attempt #{index + 1}/#{tries} stalled: #{e.message}")
        end
      end

      raise last_error
    end

    def stream_once(chat, prompt, stall)
      queue = Queue.new
      worker = Thread.new do
        Thread.current.report_on_exception = false
        begin
          message = chat.ask(prompt) { |_chunk| queue << :chunk }
          queue << [:done, message]
        rescue StandardError => e
          queue << [:error, e]
        end
      end

      loop do
        event =
          begin
            Timeout.timeout(stall) { queue.pop }
          rescue Timeout::Error
            worker.kill
            raise Stalled, "no stream data for #{stall}s"
          end

        next if event == :chunk

        kind, payload = event
        worker.join(1)
        raise payload if kind == :error

        return payload
      end
    end
    private_class_method :stream_once

    # A stalled attempt may have appended a user message / partial assistant message to the chat;
    # restore the pre-attempt state so a retry doesn't send a duplicated turn.
    def restore_messages(chat, snapshot)
      chat.instance_variable_set(:@messages, snapshot.dup) if chat.respond_to?(:messages)
    rescue StandardError
      nil
    end
    private_class_method :restore_messages
  end
end
