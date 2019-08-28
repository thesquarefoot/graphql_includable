module GraphQLIncludable
  module New
    class IncludesBuilder
      attr_reader :included_path, :includes

      def initialize(only_one_path: true)
        @only_one_path = only_one_path
        @included_path = []
        @includes = GraphQLIncludable::New::Includes.new(nil)
      end

      def includes?
        @included_path.present?
      end

      def active_record_includes
        @includes.active_record_includes
      end

      def path_leaf_includes
        leaf_includes = @includes
        included_path.each do |key|
          leaf_includes = leaf_includes[key]
        end
        leaf_includes
      end

      def path(*symbols, &block)
        raise ArgumentError, 'Can only add path once' if @included_path.present? && @only_one_path

        if symbols.present?
          first, *rest = symbols
          includes = @includes.add_child(first)
          rest.each do |key|
            includes = includes.add_child(key)
          end
        else
          includes = @includes
        end

        if block_given?
          nested = GraphQLIncludable::New::IncludesBuilder.new
          nested.instance_eval(&block)
          symbols += nested.included_path
          includes.merge_includes(nested.includes)
        end
        @included_path = symbols
      end

      def sibling_path(*symbols, &block)
        if symbols.present?
          first, *rest = symbols
          includes = @includes.add_child(first)
          rest.each do |key|
            includes = includes.add_child(key)
          end
        else
          includes = @includes
        end

        return unless block_given?
        nested = GraphQLIncludable::New::IncludesBuilder.new(only_one_path: false)
        nested.instance_eval(&block)
        includes.merge_includes(nested.includes)
      end
    end

    class ConnectionIncludesBuilder
      attr_reader :nodes_builder, :edges_builder

      def initialize
        @nodes_builder = IncludesBuilder.new
        @edges_builder = ConnectionEdgesIncludesBuilder.new
      end

      def includes?
        @nodes_builder.includes? || @edges_builder.includes?
      end

      def nodes(*symbols, &block)
        @nodes_builder.path(*symbols, &block)
      end

      def edges(&block)
        @edges_builder.instance_eval(&block)
      end
    end

    class ConnectionEdgesIncludesBuilder
      attr_reader :builder, :node_builder

      def initialize
        @builder = IncludesBuilder.new
        @node_builder = IncludesBuilder.new
      end

      def includes?
        @builder.includes? && @node_builder.includes?
      end

      def path(*symbols, &block)
        @builder.path(*symbols, &block)
      end

      def sibling_path(*symbols, &block)
        @builder.sibling_path(*symbols, &block)
      end

      def node(*symbols, &block)
        @node_builder.path(*symbols, &block)
      end
    end
  end
end
