# vim:fileencoding=utf-8

module Resque
  module Scheduler
    class Util
      # In order to upgrade to resque(1.25) which has deprecated following
      # methods, we just added these usefull helpers back to use in Resque
      # Scheduler.  refer to:
      # https://github.com/resque/resque-scheduler/pull/273

      def self.constantize(camel_cased_word)
        camel_cased_word = camel_cased_word.to_s

        if camel_cased_word.include?('-')
          camel_cased_word = classify(camel_cased_word)
        end

        names = camel_cased_word.split('::')
        names.shift if names.empty? || names.first.empty?

        constant = Object
        names.each do |name|
          args = Module.method(:const_get).arity != 1 ? [false] : []

          constant = if constant.const_defined?(name, *args)
                       constant.const_get(name)
                     else
                       constant.const_missing(name)
                     end
        end
        constant
      end

      def self.classify(dashed_word)
        dashed_word.split('-').map(&:capitalize).join
      end
    end
  end
end
