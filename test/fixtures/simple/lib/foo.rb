# frozen_string_literal: true

class Foo
  def parse(input)
    return nil if input.nil?
    raise ArgumentError if input.is_a?(Symbol)
    log_error(input) if input.empty?
    input.to_s
  end

  def log_error(msg)
    warn(msg)
  end
end
