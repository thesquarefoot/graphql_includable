module GraphQLIncludable
  class Includes
    attr_reader :included_children

    def initialize(parent_attribute)
      @parent_attribute = parent_attribute
      @included_children = {}
    end

    def add_child(key)
      return @included_children[key] if @included_children.key?(key)
      manager = Includes.new(key)
      @included_children[key] = manager
      manager
    end

    def merge_includes(includes_manager)
      includes_manager.included_children.each do |key, manager|
        included_children[key] = if included_children.key?(key)
                                   included_children[key].merge_includes(manager)
                                 else
                                   manager
                                 end
      end
      self
    end

    def [](key)
      @included_children[key]
    end

    def dig(*args)
      args = args[0] if args.length == 1 && args[0].is_a?(Array)
      return @included_children if args.empty?
      @included_children.dig(*args)
    end

    def empty?
      @included_children.empty?
    end

    def active_record_includes
      child_includes = {}
      child_includes_arr = []
      @included_children.each do |key, value|
        if value.empty?
          child_includes_arr << key
        else
          active_record_includes = value.active_record_includes
          if active_record_includes.is_a?(Array)
            child_includes_arr += active_record_includes
          else
            child_includes.merge!(active_record_includes)
          end
        end
      end

      if child_includes_arr.present?
        child_includes_arr << child_includes if child_includes.present?
        child_includes = child_includes_arr
      end

      return child_includes if @parent_attribute.nil?
      { @parent_attribute => child_includes }
    end
  end
end
