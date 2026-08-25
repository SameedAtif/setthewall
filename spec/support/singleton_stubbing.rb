# Minitest 6 dropped `minitest/mock` (and therefore Object#stub), so these helpers
# stub singleton methods by hand: capture the original, override, yield, restore.
module SingletonStubbing
  def stub_singleton(klass, name, value)
    original = klass.method(name)
    klass.define_singleton_method(name) do |*args, **kwargs|
      value.respond_to?(:call) ? value.call(*args, **kwargs) : value
    end
    yield
  ensure
    klass.define_singleton_method(name, original)
  end
end
