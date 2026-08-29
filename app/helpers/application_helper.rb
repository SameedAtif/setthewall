module ApplicationHelper
  # Tailwind classes for a status badge.
  def status_color(status)
    case status
    when "complete"          then "bg-green-100 text-green-800"
    when "awaiting_human"    then "bg-amber-100 text-amber-800"
    when "failed"            then "bg-red-100 text-red-800"
    when "running"           then "bg-blue-100 text-blue-800"
    else "bg-gray-100 text-gray-700"   # pending, open, etc.
    end
  end
end
