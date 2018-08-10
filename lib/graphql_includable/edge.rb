module GraphQLIncludable
  class Edge < GraphQL::Relay::Edge
    # Retrieve the record representing the edge between node and parent
    def edge_record
      return @edge_record if @edge_record.present?

      record_set = associations_between_node_and_parent.reverse.reduce(parent) { |acc, cur| acc.send(cur) }
      if record_set.loaded?
        @edge_record ||= record_set.first do |rec|
          rec.send(root_association_key) == parent &&
          rec.send(node.class.name.downcase.to_sym) == node
        end
      else
        first_association, *nested_associations = associations_between_node_and_parent
        edge_class = self.class.str_to_class(first_association)
        root_association_key = root_association_key(edge_class)

        selector = edge_class

        if nested_associations.present?
          nested_association_names = nested_associations.map { |s| s.to_s.singularize }
          selector = selector.merge(edge_class.includes(*nested_association_names))
        end

        if class_is_polymorphic?(edge_class)
          selector = selector.merge(edge_class.joins(root_association_key))
        end

        @edge_record = selector.find_by(
          where_hash_for_edge(root_association_key, nested_associations)
        )
      end
    end

    def class_is_polymorphic?(klass)
      klass.reflections.any? { |_k, r| r.polymorphic? }
    end

    # Delegate method calls on this Edge instance to the ActiveRecord instance
    def method_missing(method_name, *args, &block)
      return super unless edge_record.respond_to?(method_name)
      edge_record.send(method_name, *args, &block)
    end

    def respond_to_missing?(method_name, include_private = false)
      edge_record.respond_to?(method_name) || super
    end

    private

    # List all HasManyThrough associations between node and parent models
    def associations_between_node_and_parent
      return @associations if @associations.present?

      associations = []
      association_name = node.class.name.pluralize.downcase.to_sym
      association = parent.class.reflect_on_association(association_name)
      while association.is_a?(ActiveRecord::Reflection::ThroughReflection)
        associations.unshift(association.options[:through])
        association = parent.class.reflect_on_association(association.options[:through])
      end

      @associations = associations
    end

    # List the key:value criteria for finding the edge record in the database
    def where_hash_for_edge(root_key, nested_associations)
      root_include = { root_key => [parent] }
      terminal_include = { self.class.class_to_str(node.class) => node }
      inner_includes = nested_associations.reverse.reduce(terminal_include) do |acc, rel_name|
        { rel_name.to_s.pluralize => acc }
      end
      root_include.merge(inner_includes)
    end

    def root_association_key(edge_class)
      key = self.class.class_to_str(parent.class)
      unless edge_class.reflections.keys.include?(key)
        key = edge_class.reflections.select { |_k, r| r.polymorphic? }.keys.first
      end
      key.to_sym
    end

    class << self
      def str_to_class(str)
        str.to_s.singularize.camelize.constantize
      rescue # rubocop:disable Lint/HandleExceptions
      end

      def class_to_str(klass)
        klass.name.downcase
      end
    end
  end
end
