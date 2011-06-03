
require 'rest-core/middleware'

class RestCore::Defaults
  def self.members; [:defaults]; end
  include RestCore::Middleware

  def initialize app, defaults
    super
    singleton_class.module_eval do
      defaults.each{ |(key, value)|
        define_method(key) do |env|
          value
        end
      }
    end
  end
end