GraphQL::Field.accepts_definitions(
  ##
  # Define Active Record includes for a field
  new_includes: GraphQL::Define.assign_metadata_key(:new_includes),
)

module GraphQLIncludable
  module New
    class Resolver
      def initialize(ctx)
        @root_ctx = ctx
      end

      def includes_for_node(node, includes)
        return includes_for_top_level_connection(node, includes) if node.definition.connection?

        children = node.scoped_children[node.return_type.unwrap]
        children.each_value do |child_node|
          includes_for_child(child_node, includes)
        end
      end

      private

      def includes_for_child(node, includes)
        return includes_for_connection(node, includes) if node.definition.connection?

        builder = build_includes(node)
        return unless builder&.includes?

        includes.merge_includes(builder.includes)

        # Determine which [nested] child Includes manager to send to the children
        child_includes = builder.path_leaf_includes

        children = node.scoped_children[node.return_type.unwrap]
        children.each_value do |child_node|
          includes_for_child(child_node, child_includes)
        end
      end

      def includes_for_connection(node, includes)
        builder = build_connection_includes(node)
        return unless builder&.includes?

        connection_children = node.scoped_children[node.return_type.unwrap]
        connection_children.each_value do |connection_node|
          # connection_field {
          #   totalCount
          #   pageInfo {...}
          #   nodes {
          #     node_model_field ...
          #   }
          #   edges {
          #     edge_model_field ...
          #     node {
          #       node_model_field ...
          #     }
          #   }
          # }

          if connection_node.name == 'edges'
            edges_includes_builder = builder.edges_builder.builder
            includes.merge_includes(edges_includes_builder.includes)
            edges_includes = edges_includes_builder.path_leaf_includes

            edge_children = connection_node.scoped_children[connection_node.return_type.unwrap]
            edge_children.each_value do |edge_child_node|
              if edge_child_node.name == 'node'
                node_includes_builder = builder.edges_builder.node_builder
                edges_includes.merge_includes(node_includes_builder.includes)
                edge_node_includes = node_includes_builder.path_leaf_includes

                node_children = edge_child_node.scoped_children[edge_child_node.return_type.unwrap]
                node_children.each_value do |node_child_node|
                  includes_for_child(node_child_node, edge_node_includes)
                end
              else
                includes_for_child(edge_child_node, edges_includes)
              end
            end
          elsif connection_node.name == 'nodes'
            nodes_includes_builder = builder.nodes_builder
            includes.merge_includes(nodes_includes_builder.includes)
            nodes_includes = nodes_includes_builder.path_leaf_includes

            node_children = connection_node.scoped_children[connection_node.return_type.unwrap]
            node_children.each_value do |node_child_node|
              includes_for_child(node_child_node, nodes_includes)
            end
          elsif connection_node.name == 'totalCount'
            # Handled using `.size` - if includes() grabbed edges/nodes it will .length else, a COUNT query saving memory.
          end
        end
      end

      # Special case:
      # When includes_for_node is called within a connection resolver, there is no need to use that field's nodes/edges
      # includes, only edge_to_node includes
      def includes_for_top_level_connection(node, includes)
        builder = build_connection_includes(node)
        return unless builder&.edges_builder.node_builder&.includes?

        connection_children = node.scoped_children[node.return_type.unwrap]
        top_level_being_resolved = @root_ctx.namespace(:gql_includable)[:resolving]

        if top_level_being_resolved == :edges
          edges_node = connection_children['edges']
          edges_includes = includes

          edge_children = edges_node.scoped_children[edges_node.return_type.unwrap]
          edge_children.each_value do |edge_child_node|
            if edge_child_node.name == 'node'
              node_includes_builder = builder.edges_builder.node_builder
              edges_includes.merge_includes(node_includes_builder.includes)
              edge_node_includes = node_includes_builder.path_leaf_includes

              node_children = edge_child_node.scoped_children[edge_child_node.return_type.unwrap]
              node_children.each_value do |node_child_node|
                includes_for_child(node_child_node, edge_node_includes)
              end
            else
              includes_for_child(edge_child_node, edges_includes)
            end
          end
        else
          nodes_node = connection_children['nodes']
          return unless nodes_node.present?
          nodes_includes = includes

          node_children = nodes_node.scoped_children[nodes_node.return_type.unwrap]
          node_children.each_value do |node_child_node|
            includes_for_child(node_child_node, nodes_includes)
          end
        end
      end

      def build_includes(node)
        includes_meta = node.definition.metadata[:new_includes]
        return nil if includes_meta.blank?

        builder = GraphQLIncludable::New::IncludesBuilder.new()

        if includes_meta.is_a?(Proc)
          if includes_meta.arity == 2
            args_for_field = @root_ctx.query.arguments_for(node, node.definition)
            builder.instance_exec(args_for_field, @root_ctx, &includes_meta)
          else
            builder.instance_exec(&includes_meta)
          end
        else
          builder.path(includes_meta)
        end

        builder
      end

      def build_connection_includes(node)
        includes_meta = node.definition.metadata[:new_includes]
        return nil if includes_meta.blank?

        builder = GraphQLIncludable::New::ConnectionIncludesBuilder.new()
        if includes_meta.arity == 2
          args_for_field = @root_ctx.query.arguments_for(node, node.definition)
          builder.instance_exec(args_for_field, @root_ctx, &includes_meta)
        else
          builder.instance_exec(&includes_meta)
        end
        builder
      end
    end
  end
end
