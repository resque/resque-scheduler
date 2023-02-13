# vim:fileencoding=utf-8

module Resque
  module Scheduler
    class Util
      # In order to upgrade to resque(1.25) which has deprecated following
      # methods, we just added these useful helpers back to use in Resque
      # Scheduler.  refer to:
      # https://github.com/resque/resque-scheduler/pull/273

      CLASSIFY_DELIMETERS = %w(- _).freeze

      def self.constantize(camel_cased_word)
        camel_cased_word = camel_cased_word.to_s

        unless (camel_cased_word.chars & CLASSIFY_DELIMETERS).empty?
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
        CLASSIFY_DELIMETERS.each do |delimiter|
          dashed_word = dashed_word.split(delimiter)
                                   .map { |w| w[0].capitalize + w[1..-1] }
                                   .join
        end
        dashed_word
      end
    end
  end
end
