require 'active_support/concern'

module GraphQLIncludable
  module Concern
    extend ActiveSupport::Concern

    module ClassMethods
      def includes_from_graphql(ctx)
        node = Resolver.find_node_by_return_type(ctx.irep_node, name)
        manager = IncludesManager.new(nil)
        Resolver.includes_for_node(node, manager)
        puts "INCLUDES #{manager.includes}"
        includes(manager.includes)
      rescue => e
        Rails.logger.error(e)
        self
      end

      def delegate_cache
        @delegate_cache ||= {}
      end

      def delegate(*methods, args)
        methods.each do |method|
          delegate_cache[method] = args[:to]
        end
        super(*methods, args) if defined?(super)
      end
    end
  end
end
