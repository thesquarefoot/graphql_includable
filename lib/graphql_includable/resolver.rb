# Includes = Symbol | Array<Symbol> | Hash<Symbol, Includes>
module GraphQLIncludable
  class Resolver
    class << self
      # Returns the first node in the tree which returns a specific type
      # @param node GraphQL::InternalRepresentation::Node
      # @param desired_return_type String
      # @returns matching_node GraphQL::InternalRepresentation::Node
      def find_node_by_return_type(node, desired_return_type)
        return_type = node.return_type.unwrap.to_s
        return node if return_type == desired_return_type
        return unless node.respond_to?(:scoped_children)
        matching_node = nil
        node.scoped_children.values.each do |selections|
          matching_node = selections.values.find do |child_node|
            find_node_by_return_type(child_node, desired_return_type)
          end
          break if matching_node
        end
        matching_node
      end

      # Collect preloadable relationships for the resolution of `node`
      #
      # @param node GraphQL::InternalRepresentation::Node
      # @returns includes Includes
      def includes_for_node(node)
        return_model = node_return_model(node)
        return [] if return_model.blank?
        children = node.scoped_children[node.return_type.unwrap]
        child_includes = children.map { |_key, child| includes_for_node_child(child, return_model) }
        combine_child_includes(child_includes)
      end

      # Collect preloadable relationships for all selections on `node`,
      # as accessed from `parent_model`.
      #
      # @param node GraphQL::InternalRepresentation::Node
      # @param parent_model ActiveRecord::Base
      # @returns child_includes Includes
      def includes_for_node_child(node, parent_model)
        included_attributes = node_includes_source_from_metadata(node)
        return included_attributes if included_attributes.is_a?(Hash)
        included_attributes = [included_attributes] unless included_attributes.is_a?(Array)
        includes = included_attributes.map do |attribute_name|
          includes_for_node_child_attribute(node, parent_model, attribute_name)
        end
        includes.size == 1 ? includes.first : includes
      end

      # Collect preloadable relationships for a single selection on `node`,
      # as accessed from `parent_model`
      #
      # @param node GraphQL::InternalRepresentation::Node
      # @param parent_model ActiveRecord::Base
      # @param attribute_name Symbol
      # @returns includes Includes
      def includes_for_node_child_attribute(node, parent_model, attribute_name)
        includes_array = includes_delegated_through(parent_model, attribute_name)
        target_model = model_name_to_class(includes_array.last) || parent_model
        association = target_model.reflect_on_association(attribute_name)

        if association && node_is_relay_connection?(node)
          includes_array << includes_for_node_relay_child_attribute(
            node, attribute_name, association
          )
        elsif association
          includes_array += [attribute_name, includes_for_node(node)]
        end
        array_to_nested_hash(includes_array)
      end

      # Collect preloadable relationships for a single selection on `node`,
      # as accessed from `parent_model`, through the Relay specification's
      # named `edges` and `nodes` selections.
      #
      # @param node GraphQL::InternalRepresentation::Node
      # @param attribute_name Symbol
      # @param association ActiveRecord::HasManyThroughAssociation
      def includes_for_node_relay_child_attribute(node, attribute_name, association)
        children = node.scoped_children[node.return_type.unwrap]

        edge_data = includes_for_node_relay_child_edge_attribute(
          children['edges'], attribute_name, association
        )
        leaf_data = [attribute_name, includes_for_node(node)] if children['nodes']

        [array_to_nested_hash(edge_data), array_to_nested_hash(leaf_data)].reject(&:blank?)
      end

      # Collect preloadable relationships for a single selection on `node`,
      # a Relay Edge node whose parent is a Connection being accessed from `parent_model`
      #
      # @param node GraphQL::InternalRepresentation::Node
      # @param attribute_name Symbol
      # @param association ActiveRecord::HasManyThroughAssociation
      def includes_for_node_relay_child_edge_attribute(node, attribute_name, association)
        return unless node
        leaf_includes = [attribute_name.to_s.singularize.to_sym]
        edge_children = node.scoped_children[node.return_type.unwrap]
        if edge_children['node']
          leaf_includes << includes_for_node(edge_children['node'])
        end
        leaf_includes = array_to_nested_hash(leaf_includes)

        [association.options[:through], [*includes_for_node(node), leaf_includes]]
      end

      # Format child includes into a data structure that can be preloaded
      # Singular terminal nodes become symbols,
      # multiple terminal nodes become arrays of symbols,
      # and branching nodes become hashes.
      # The result can be passed directly into ActiveModel::Base.includes
      #
      # @param child_includes Includes
      # @returns child_includes Includes
      def combine_child_includes(child_includes)
        includes = []
        nested_includes = {}
        child_includes.each do |child|
          if child.is_a?(Hash)
            nested_includes.merge!(child)
          elsif child.is_a?(Array)
            includes += child
          else
            includes << child
          end
        end
        includes << nested_includes if nested_includes.present?
        includes.uniq.reject(&:blank?)
      end

      # Retrieve the Ruby class for a model by name
      # Attempts to singularize the name if not found
      #
      # @param model_name Symbol | String
      # @returns klass Class
      def model_name_to_class(model_name)
        begin
          model_name.to_s.camelize.constantize
        rescue NameError
          model_name.to_s.singularize.camelize.constantize
        end
      rescue # rubocop:disable Lint/HandleExceptions
      end

      # Translate a node's return type to an ActiveRecord model
      #
      # @param node GraphQL::InternalRepresentation::Node
      # @returns model ActiveRecord::Base | nil
      REGEX_CLEAN_GQL_TYPE_NAME = /(^SquareFoot|Edge$|Connection$)/
      def node_return_model(node)
        model = Object.const_get(node.return_type.unwrap.name.gsub(REGEX_CLEAN_GQL_TYPE_NAME, ''))
        model if model < ActiveRecord::Base
      rescue NameError # rubocop:disable Lint/HandleExceptions
      end

      # @param node GraphQL::InternalRepresentation::Node
      # @returns is_relay_connection Boolean
      REGEX_RELAY_CONNECTION = /Connection$/
      def node_is_relay_connection?(node)
        node.return_type.unwrap.name =~ REGEX_RELAY_CONNECTION
      end

      # Predict the association name to include from a field's metadata
      #
      # @param node GraphQL::InternalRepresentation::Node
      # @returns possible_includes Includes
      def node_includes_source_from_metadata(node)
        definition = node.definitions.first
        definition.metadata[:includes] || (definition.property || definition.name).to_sym
      end

      # If method_name is delegated from base_model, return an array of
      # associations through which those methods can be delegated
      #
      # @param base_model ActiveRecord::Base
      # @param method_name String | Symbol
      # @returns chain Array<Symbol>
      def includes_delegated_through(base_model, method_name)
        chain = []
        method = method_name.to_sym
        model_name = base_model.instance_variable_get(:@delegate_cache).try(:[], method)
        while model_name
          chain << model_name
          model = model_name_to_class(model_name)
          model_name = model.instance_variable_get(:@delegate_cache).try(:[], method)
        end
        chain
      end

      # Right-reduce an array into a nested hash
      #
      # @param arr Array<Includes>
      # @returns nested_hash Includes
      def array_to_nested_hash(arr)
        (arr || []).reject(&:blank?)
                   .reverse
                   .inject { |acc, item| { item => acc } } || {}
      end
    end
  end
end
