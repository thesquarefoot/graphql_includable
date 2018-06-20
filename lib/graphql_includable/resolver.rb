module GraphQLIncludable
  class Resolver
    class << self
      # Returns the first node in the tree which returns a specific type
      def find_node_by_return_type(node, desired_return_type)
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
      def includes_for_node(node)
        return_model = node_return_model(node)
        return [] if return_model.blank?
        children = node.scoped_children[node.return_type.unwrap]
        child_includes = children.map { |_key, child| includes_for_child(child, return_model) }
        combine_child_includes(child_includes)
      end

      def includes_for_child(node, parent_model)
        attribute_name = node_predicted_association_name(node)
        delegated_through = includes_delegated_through(parent_model, attribute_name)
        delegated_model = model_name_to_class(delegated_through.last) if delegated_through.present?
        association = (delegated_model || parent_model).reflect_on_association(attribute_name)
        interceding_includes = []
        # association = get_model_association(parent_model, attribute_name, interceding_includes)

        if association
          child_includes = includes_for_node(node)
          array_to_nested_hash(interceding_includes + [attribute_name, child_includes].reject(&:blank?))
          # if node_is_relay_connection?(node)
          #   join_name = association.options[:through]
          #   edge_includes_chain = [association.name]
          #   edge_includes_chain << child_includes.pop[association.name.to_s.singularize.to_sym] if child_includes.last&.is_a?(Hash)
          #   edge_includes = array_to_nested_hash(edge_includes_chain)
          # end
        else
          # TODO: specified includes?
          [array_to_nested_hash(interceding_includes)].reject(&:blank?)
        end
      end

      # Format child includes into a data structure that can be preloaded
      # Singular terminal nodes become symbols,
      # multiple terminal nodes become arrays of symbols,
      # and branching nodes become hashes.
      # The result can be passed directly into ActiveModel::Base.includes
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
        includes.uniq
      end

      # Retrieve the Ruby class for a model by name
      # Attempts to singularize the name if not found
      def model_name_to_class(model_name)
        begin
          model_name.to_s.camelize.constantize
        rescue NameError
          model_name.to_s.singularize.camelize.constantize
        end
      rescue
      end

      # Translate a node's return type to an ActiveRecord model
      def node_return_model(node)
        model = Object.const_get(node.return_type.unwrap.name.gsub(/(^SquareFoot|Edge$|Connection$)/, ''))
        model if model < ActiveRecord::Base
      rescue NameError
      end

      # Predict the association name to include from a field's metadata
      def node_predicted_association_name(node)
        definition = node.definitions.first
        definition.metadata[:includes] || (definition.property || definition.name).to_sym
      end

      # If method_name is delegated from base_model, return an array of
      # associations through which those methods can be delegated
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
      def array_to_nested_hash(arr)
        arr.reverse.inject { |acc, item| { item => acc } } || {}
      end
    end
  end
end
