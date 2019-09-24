GraphQL::Field.accepts_definitions(
  ##
  # Define Active Record includes for a field
  includes: GraphQL::Define.assign_metadata_key(:includes)
)

module GraphQLIncludable
  class Resolver
    def initialize(ctx)
      @root_ctx = ctx
    end

    def includes_for_node(node, includes)
      return includes_for_top_level_connection(node, includes) if node.definition.connection?

      children = node.scoped_children[node.return_type.unwrap]
      children.each_value do |child_node|
        definition_override = node_definition_override(node, child_node)
        includes_for_child(child_node, includes, definition_override)
      end
    end

    private

    def includes_for_child(node, includes, definition_override)
      return includes_for_connection(node, includes, definition_override) if node.definition.connection?

      builder = build_includes(node, definition_override)
      return unless builder.present?
      includes.merge_includes(builder.includes) unless builder.includes.empty?

      return unless builder.includes?

      # Determine which [nested] child Includes manager to send to the children
      child_includes = includes.dig(builder.included_path)

      children = node.scoped_children[node.return_type.unwrap]
      children.each_value do |child_node|
        definition_override = node_definition_override(node, child_node)
        includes_for_child(child_node, child_includes, definition_override)
      end
    end

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable Metrics/MethodLength
    def includes_for_connection(node, includes, definition_override)
      builder = build_connection_includes(node, definition_override)
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
                definition_override = node_definition_override(edge_child_node, node_child_node)
                includes_for_child(node_child_node, edge_node_includes, definition_override)
              end
            else
              definition_override = node_definition_override(connection_node, edge_child_node)
              includes_for_child(edge_child_node, edges_includes, definition_override)
            end
          end
        elsif connection_node.name == 'nodes'
          nodes_includes_builder = builder.nodes_builder
          includes.merge_includes(nodes_includes_builder.includes)
          nodes_includes = nodes_includes_builder.path_leaf_includes

          node_children = connection_node.scoped_children[connection_node.return_type.unwrap]
          node_children.each_value do |node_child_node|
            definition_override = node_definition_override(connection_node, node_child_node)
            includes_for_child(node_child_node, nodes_includes, definition_override)
          end
        elsif connection_node.name == 'totalCount'
          # Handled using `.size`
        end
      end
    end

    # Special case:
    # When includes_for_node is called within a connection resolver, there is no need to use that field's nodes/edges
    # includes, only edge_to_node includes
    def includes_for_top_level_connection(node, includes)
      connection_children = node.scoped_children[node.return_type.unwrap]
      top_level_being_resolved = @root_ctx.namespace(:gql_includable)[:resolving]

      if top_level_being_resolved == :edges
        builder = build_connection_includes(node, nil)
        return unless builder&.edges_builder&.node_builder&.includes?

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
              definition_override = node_definition_override(edge_child_node, node_child_node)
              includes_for_child(node_child_node, edge_node_includes, definition_override)
            end
          else
            definition_override = node_definition_override(edges_node, edge_child_node)
            includes_for_child(edge_child_node, edges_includes, definition_override)
          end
        end
      else
        nodes_node = connection_children['nodes']
        return unless nodes_node.present?
        nodes_includes = includes

        node_children = nodes_node.scoped_children[nodes_node.return_type.unwrap]
        node_children.each_value do |node_child_node|
          definition_override = node_definition_override(nodes_node, node_child_node)
          includes_for_child(node_child_node, nodes_includes, definition_override)
        end
      end
    end
    # rubocop:enable Metrics/MethodLength
    # rubocop:enable Metrics/AbcSize

    def build_includes(node, definition_override)
      definition = definition_override || node.definition
      includes_meta = definition.metadata[:includes]
      return nil if includes_meta.blank?

      builder = GraphQLIncludable::IncludesBuilder.new

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

    def build_connection_includes(node, definition_override)
      definition = definition_override || node.definition
      includes_meta = definition.metadata[:includes]
      return nil if includes_meta.blank?

      builder = GraphQLIncludable::ConnectionIncludesBuilder.new
      if includes_meta.arity == 2
        args_for_field = @root_ctx.query.arguments_for(node, node.definition)
        builder.instance_exec(args_for_field, @root_ctx, &includes_meta)
      else
        builder.instance_exec(&includes_meta)
      end
      builder
    end

    def node_definition_override(parent_node, child_node)
      node_return_type = parent_node.return_type.unwrap
      child_node_parent_type = child_node.parent.return_type.unwrap

      return nil unless child_node_parent_type != node_return_type
      child_node_definition_override = nil
      # Handle GraphQL interface with overridden fields
      # GraphQL makes child_node.return_type the interface instance
      # and therefore takes the metadata from the interface rather than the
      # implementing object's overridden field instance
      is_interface = node_return_type.interfaces.include?(child_node_parent_type)
      child_node_definition_override = node_return_type.fields[child_node.name] if is_interface
      child_node_definition_override
    end
  end
end
