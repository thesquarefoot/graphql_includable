module GraphQLIncludable
  class IncludesManager
    def initialize(parent_attribute)
      @parent_attribute = parent_attribute
      @included_children = {}
    end

    def add_child_include(association)
      return @included_children[association.name] if @included_children.key?(association.name)

      manager = IncludesManager.new(association.name)
      @included_children[association.name] = manager
      manager
    end

    def empty?
      @included_children.empty?
    end

    def includes
      child_includes = {}
      child_includes_arr = []
      @included_children.each do |key, value|
        if value.empty?
          child_includes_arr << key
        else
          includes = value.includes
          if includes.is_a?(Array)
            child_includes_arr += includes
          else
            child_includes.merge!(includes)
          end
        end
      end

      if child_includes_arr.present?
        child_includes_arr << child_includes if child_includes.present?
        child_includes =  child_includes_arr
      end

      return child_includes if @parent_attribute.nil?
      { @parent_attribute => child_includes }
    end
  end

  class Resolver
    # Returns the first node in the tree which returns a specific type
    def self.find_node_by_return_type(node, desired_return_type)
      return_type = node.return_type.unwrap.to_s
      return node if return_type == desired_return_type
      if node.respond_to?(:scoped_children)
        matching_node = nil
        node.scoped_children.values.each do |selections|
          matching_node = selections.values.find do |child_node|
            find_node_by_return_type(child_node, desired_return_type)
          end
          break if matching_node
        end
        matching_node
      end
    end

    # Translate a node's selections into `includes` values
    # Combine and format children values
    # Noop on nodes that don't return AR (so no associations to include)
    def self.includes_for_node(node, includes_manager)
      return_model = node_return_model(node)
      return [] if return_model.blank?

      children = node.scoped_children[node.return_type.unwrap]

      children.each_value do |child_node|
        includes_for_child(child_node, return_model, includes_manager)
      end
    end

    def self.includes_from_connection(node, parent_model, association_from_parent_model, includes_manager)
      return unless node.return_type.fields['edges'].edge_class <= GraphQLIncludable::EdgeWithNode

      # Need to figure out if it works right for both edges and nodes directly. Even better if it doesn't load edges to get nodes

      edge_node_attribute = node.return_type.fields['edges'].metadata[:edge_to_node_property]
      edge_model = association_from_parent_model.klass
      edge_to_node_association = edge_model.reflect_on_association(edge_node_attribute)
      node_model = edge_to_node_association.klass

      connection_children = node.scoped_children[node.return_type.unwrap]
      connection_children.each_value do |connection_node|
        # connection_field {
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
          edge_children = connection_node.scoped_children[connection_node.return_type.unwrap]
          edge_children.each_value do |edge_child_node|
            if edge_child_node.name == 'node'
              child_includes_manager = includes_manager.add_child_include(edge_to_node_association)

              node_children = edge_child_node.scoped_children[edge_child_node.return_type.unwrap]
              node_children.each_value do |node_child_node|
                includes_for_child(node_child_node, node_model, child_includes_manager)
              end
            else
              includes_for_child(edge_child_node, edge_model, includes_manager)
            end
          end
        elsif connection_node.name == 'nodes'
          child_includes_manager = includes_manager.add_child_include(edge_to_node_association)
          node_children = connection_node.scoped_children[connection_node.return_type.unwrap]
          node_children.each_value do |node_child_node|
            includes_for_child(node_child_node, node_model, child_includes_manager)
          end
        end
      end
    end

    def self.includes_for_child(node, parent_model, includes_manager)
      attribute_name = node_predicted_association_name(node)
      delegated_through = includes_delegated_through(parent_model, attribute_name)
      delegated_model = model_name_to_class(delegated_through.last) if delegated_through.present?
      association = (delegated_model || parent_model).reflect_on_association(attribute_name)

      if association
        child_includes_manager = includes_manager.add_child_include(association)
        if node_is_relay_connection?(node)
          includes_from_connection(node, parent_model, association, child_includes_manager)
        else
          includes_for_node(node, child_includes_manager)
        end
      end
    end

    def self.model_name_to_class(model_name)
      begin
        model_name.to_s.camelize.constantize
      rescue NameError
        model_name.to_s.singularize.camelize.constantize
      end
    rescue
    end

    # Translate a node's return type to an ActiveRecord model
    def self.node_return_model(node)
      model = Object.const_get(node.return_type.unwrap.name.gsub(/(^SquareFoot|Edge$|Connection$)/, ''))
      model if model < ActiveRecord::Base
    rescue NameError
    end

    def self.node_predicted_association_name(node)
      definition = node.definitions.first
      definition.metadata[:edges_property] || definition.metadata[:includes] || (definition.property || definition.name).to_sym
    end

    # If method_name is delegated from base_model, return an array of
    # associations through which those methods can be delegated
    def self.includes_delegated_through(base_model, method_name)
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
    def self.array_to_nested_hash(arr)
      arr.reverse.inject { |acc, item| { item => acc } } || {}
    end

    def self.node_is_relay_connection?(node)
      node.return_type.unwrap.name =~ /Connection$/
    end
  end
end
