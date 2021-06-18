require_relative 'RubyClassPatches'

def create_options(h) # :nodoc:
  result = (Class.new {
    attr_reader *(h.keys.reject {|key| key.to_s.end_with?('?')})

    h.each_key { |key|
      next unless key.to_s.end_with?('?')
      define_method(key.to_s) {
        instance_variable_get("@#{key.to_s[0...-1]}")
      }
    }
  }).new
  h.each { |key, value|
    key = key.to_s[0...-1].to_sym if key.to_s.end_with?('?')
    result.instance_variable_set("@#{key}", value)
  }
  result
end

class Object
##
# :singleton-method: opt
# :call-seq:
#   opt(name, required, value_required, opts = nil) -> nil
#
# Temporary method that exists only within CommandLineParser.parse method's block.
# The method defines an option with the name *name*. +Name+ can be +Integer+, +String+ or +Symbol+. +name.to_s+ will be used to produce text representation
# of the option in command line.
#
# ==== Flag
# <i>A flag option cannot be required.</i>
#   opt :i, :optional, :flag
#
#   ''       #=> {i: false}
#   '-i'     #=> {i: true}
#
# ==== Option with a string value
# An option with an arbitrary non empty string value:
#   opt :i, :optional, :has_value
#
#   ''       #=> {}
#   '-i:abc' #=> {i: 'abc'}
#   '-i'     #=> error
#
# An option with a non empty string value that should match the given regex:
#   opt :i, :optional, :has_value, value_pattern: /\A\d*\z/
#
#   ''       #=> {}
#   '-i:123' #=> {i: '123'}
#   '-i:abc' #=> error
#   '-i'     #=> error
#
# An option with an optional arbitrary non empty string value:
#   opt :i, :optional, :opt_value
#
#   ''       #=> {}
#   '-i:abc' #=> {i: 'abc'}
#   '-i'     #=> {i: nil}
#
#   opt :i, :optional, :opt_value, default_value: :none
#
#   ''       #=> {}
#   '-i:abc' #=> {i: 'abc'}
#   '-i'     #=> {i: :none}
#
# An option with an optional non empty string value that should match the given regex:
#   opt :i, :optional, :opt_value, value_pattern: /\A\d*\z/
#
#   ''       #=> {}
#   '-i:123' #=> {i: '123'}
#   '-i:abc' #=> error
#   '-i'     #=> {i: nil}
#
#   opt :i, :optional, :opt_value, value_pattern: /\A\d*\z/, default_value: :none
#
#   ''       #=> {}
#   '-i:123' #=> {i: '123'}
#   '-i:abc' #=> error
#   '-i'     #=> {i: :none}
#
# ==== Option with several string values
# An option with several arbitrary non empty string values:
#   opt :i, :optional, :has_value, multiple_of: nil
#
#   ''         #=> {}
#   '-i:ab'    #=> {i: %w[ab]}
#   '-i:ab,cd' #=> {i: %w[ab cd]}
#   '-i:ab,aB' #=> error
#   '-i'       #=> error
#
#   opt :i, :optional, :has_value, multiple_of: nil, alternative_value: :ui
#
#   ''         #=> {}
#   '-i:ab'    #=> {i: %w[ab]}
#   '-i:ab,cd' #=> {i: %w[ab cd]}
#   '-i:ab,aB' #=> error
#   '-i:ui'    #=> {i: :ui}
#   '-i:ui,ab' #=> error
#   '-i'       #=> error
#
# An option with several non empty string values that should match the given regex:
#   opt :i, :optional, :has_value, multiple_of: /\A\d*\z/
#
#   ''         #=> {}
#   '-i:12'    #=> {i: %w[12]}
#   '-i:12,23' #=> {i: %w[12 23]}
#   '-i:12,12' #=> error
#   '-i:ab'    #=> error
#   '-i'       #=> error
#
#   opt :i, :optional, :has_value, multiple_of: /\A\d*\z/, alternative_value: :ui
#
#   ''         #=> {}
#   '-i:12'    #=> {i: %w[12]}
#   '-i:12,23' #=> {i: %w[12 23]}
#   '-i:12,12' #=> error
#   '-i:ab'    #=> error
#   '-i:ui'    #=> {i: :ui}
#   '-i:ui,12' #=> error
#   '-i'       #=> error
#
# An option with optionally several arbitrary non empty string values:
#   opt :i, :optional, :opt_value, multiple_of: nil
#
#   ''         #=> {}
#   '-i:ab'    #=> {i: %w[ab]}
#   '-i:ab,cd' #=> {i: %w[ab cd]}
#   '-i:ab,aB' #=> error
#   '-i'       #=> {i: nil}
#
#   opt :i, :optional, :opt_value, multiple_of: nil, alternative_value: :ui
#
#   ''         #=> {}
#   '-i:ab'    #=> {i: %w[ab]}
#   '-i:ab,cd' #=> {i: %w[ab cd]}
#   '-i:ab,aB' #=> error
#   '-i:ui'    #=> {i: :ui}
#   '-i:ui,ab' #=> error
#   '-i'       #=> {i: nil}
#
#   opt :i, :optional, :opt_value, multiple_of: nil, default_value: :none
#
#   ''         #=> {}
#   '-i:ab'    #=> {i: %w[ab]}
#   '-i:ab,cd' #=> {i: %w[ab cd]}
#   '-i:ab,aB' #=> error
#   '-i'       #=> {i: :none}
#
#   opt :i, :optional, :opt_value, multiple_of: nil, alternative_value: :ui, default_value: :none
#
#   ''         #=> {}
#   '-i:ab'    #=> {i: %w[ab]}
#   '-i:ab,cd' #=> {i: %w[ab cd]}
#   '-i:ab,aB' #=> error
#   '-i:ui'    #=> {i: :ui}
#   '-i:ui,ab' #=> error
#   '-i'       #=> {i: :none}
#
# An option with optionally several non empty string values that should match the given regex:
#   opt :i, :optional, :opt_value, multiple_of: /\A\d*\z/
#
#   ''         #=> {}
#   '-i:12'    #=> {i: %w[12]}
#   '-i:12,23' #=> {i: %w[12 23]}
#   '-i:12,12' #=> error
#   '-i:ab'    #=> error
#   '-i'       #=> {i: nil}
#
#   opt :i, :optional, :opt_value, multiple_of: /\A\d*\z/, alternative_value: :ui
#
#   ''         #=> {}
#   '-i:12'    #=> {i: %w[12]}
#   '-i:12,23' #=> {i: %w[12 23]}
#   '-i:12,12' #=> error
#   '-i:ab'    #=> error
#   '-i:ui'    #=> {i: :ui}
#   '-i:ui,12' #=> error
#   '-i'       #=> {i: nil}
#
#   opt :i, :optional, :opt_value, multiple_of: /\A\d*\z/, default_value: :none
#
#   ''         #=> {}
#   '-i:12'    #=> {i: %w[12]}
#   '-i:12,23' #=> {i: %w[12 23]}
#   '-i:12,12' #=> error
#   '-i:ab'    #=> error
#   '-i'       #=> {i: :none}
#
#   opt :i, :optional, :opt_value, multiple_of: /\A\d*\z/, alternative_value: :ui, default_value: :none
#
#   ''         #=> {}
#   '-i:12'    #=> {i: %w[12]}
#   '-i:12,23' #=> {i: %w[12 23]}
#   '-i:12,12' #=> error
#   '-i:ab'    #=> error
#   '-i:ui'    #=> {i: :ui}
#   '-i:ui,12' #=> error
#   '-i'       #=> {i: :none}
#
# ==== FlagsOf
# <i>A flags_of option should be defined with :optional and :has_value.</i>
#   opt :i, :optional, :has_value, flags_of: %i[ab bc cd]
#
#   ''         #=> {i: {ab: false, bc: false, cd: false}}
#   '-i:ab'    #=> {i: {ab: true, bc: false, cd: false}}
#   '-i:bc,ab' #=> {i: {ab: true, bc: true, cd: false}}
#   '-i:bc,Bc' #=> error
#   '-i'       #=> error
#
# ==== Option with value from predefined list
# An option with a required value from the given array:
#   opt :i, :optional, :has_value, one_of: %i[ab bc cd]
#
#   ''      #=> {}
#   '-i'    #=> error
#   '-i:ab' #=> {i: :ab}
#
# An option with an optional value from the given array:
#   opt :i, :optional, :opt_value, one_of: %i[ab bc cd]
#
#   ''      #=> {}
#   '-i'    #=> {i: nil}
#   '-i:ab' #=> {i: :ab}
#
#   opt :i, :optional, :opt_value, one_of: %i[ab bc cd], default_value: :none
#
#   ''      #=> {}
#   '-i'    #=> {i: :none}
#   '-i:ab' #=> {i: :ab}
#
# ==== Option with several values from predefined list
#
# === Additional features
#
# Any optional option (except _flag_ and _flags_of_) can be supplied with default value that will be used when the option is absent:
#   opt :i, :optional, :has_value, default: false
#
#   ''       #=> {i: false}
#   '-i:abc' #=> {i: 'abc'}
#   '-i'     #=> error
#
#   opt :i, :optional, :opt_value, default: false, default_value: true
#
#   ''       #=> {i: false}
#   '-i:abc' #=> {i: 'abc'}
#   '-i'     #=> {i: true}
end

class CommandLineParser
  class << self
    # :call-seq:
    #   parse(args, &block) -> hash
    #
    # Parses arguments in +args+ which must be an array of string. +Args+ is typically a subarray of +ARGV+.
    #
    # Inside a required block use the method +opt+ to define allowed options.
    def parse(args)
      raise if Object.methods.include?(:opt)
      definitions = {}
      Object.send(:define_method, :opt, ->(name, required, value_required, opts = nil) {
        CommandLineParser.send(:add_option_definition, definitions, name, required, value_required, opts)
      })
      yield
      Object.send(:remove_method, :opt)

      parse_internal(definitions, args)
    end
    
  private

    def add_option_definition(definitions, name, required, value_required, opts = nil)
    # opts:
    #   allow_value_exclusion
    #   alternative_value
    #   caption
    #   category_caption
    #   category_name
    #   default
    #   default_value
    #   flags_of
    #   multiple_of
    #   on_select
    #   one_of
    #   show_possible_categories
    #   show_possible_values
    #   show_possible_value
    #   value_name
    #   value_pattern
      begin
        raise unless name.is_a?(Integer) || name.is_a?(String) || name.is_a?(Symbol)
        option_key = name.to_s.strip.downcase
        raise if option_key.empty? || definitions.has_key?(option_key)

        raise unless %i[optional required].include?(required)
        required = required == :required

        raise unless %i[flag has_value opt_value].include?(value_required)

        opts = {} if opts.nil?
        raise unless opts.is_a?(Hash)
        opts_keys = opts.keys

        definition = {name: name, required: required, value_required: value_required}

        if opts.has_key?(:caption)
          caption = opts[:caption]
          raise unless caption.is_a?(String)
          caption = caption.strip
          raise if caption.empty?
          definition[:caption] = caption
        end

        if value_required == :flag
          raise if required
          raise unless (opts_keys - %i[caption]).empty?
        elsif (opts_keys & %i[flags_of multiple_of one_of]).empty?
          raise if opts.has_key?(:default) && required
          raise unless (opts_keys - %i[caption default default_value show_possible_value value_name value_pattern]).empty?
          raise if opts.has_key?(:default_value) && value_required == :has_value
          raise unless opts.has_key?(:value_pattern) || (opts_keys & %i[show_possible_value value_name]).empty?

          if opts.has_key?(:default)
            definition[:default] = opts[:default]
          end

          if opts.has_key?(:default_value)
            definition[:default_value] = opts[:default_value]
          end

          if opts.has_key?(:show_possible_value)
            show_possible_value = opts[:show_possible_value]
            raise unless show_possible_value.is_a?(FalseClass) || show_possible_value.is_a?(TrueClass)
            definition[:show_possible_value] = show_possible_value
          else
            definition[:show_possible_value] = true
          end

          if opts.has_key?(:value_name)
            value_name = opts[:value_name]
            raise unless value_name.is_a?(String)
            value_name = value_name.strip
            raise if value_name.empty?
            definition[:value_name] = value_name
          else
            definition[:value_name] = 'value'
          end

          if opts.has_key?(:value_pattern)
            value_pattern = opts[:value_pattern]
            raise unless value_pattern.is_a?(Regexp)
            definition[:value_pattern] = value_pattern
          end
        else
          raise unless (opts_keys - %i[
            allow_value_exclusion
            alternative_value
            caption
            category_caption
            category_name
            default
            default_value
            flags_of
            multiple_of
            on_select
            one_of
            show_possible_categories
            show_possible_values
            value_name
          ]).empty?

          value_definition_kind = opts_keys & %i[flags_of one_of multiple_of]
          raise unless value_definition_kind.size == 1
          value_definition_kind = value_definition_kind[0]
          definition[:value_definition_kind] = value_definition_kind

          value_definition = opts[value_definition_kind]
          raise unless (value_definition.is_a?(Array) || value_definition.is_a?(Hash)) && !value_definition.empty? ||
            value_definition.is_a?(Regexp) || value_definition.nil?

          case value_definition_kind
            when :flags_of
              raise if required
              raise unless value_required == :has_value
              raise unless (opts_keys & %i[allow_value_exclusion alternative_value default on_select]).empty?
              raise unless value_definition.is_a?(Array)
            when :multiple_of
              raise if opts.has_key?(:allow_value_exclusion) && !(opts.has_key?(:on_select) && value_definition.is_a?(Array))
              raise if opts.has_key?(:default) && required
            when :one_of
              raise unless(opts_keys & %i[allow_value_exclusion alternative_value]).empty?
              raise if opts.has_key?(:default) && required
              raise unless value_definition.is_a?(Array)
          end
          raise if value_required != :opt_value && opts.has_key?(:default_value)

          if opts.has_key?(:alternative_value)
            alternative_value = opts[:alternative_value]
            alternative_value_key = alternative_value.to_s.strip.downcase
            raise unless key_valid?(alternative_value_key)
            definition[:alternative_value] = alternative_value
          end

          if value_definition.is_a?(Array)
            raise unless (opts_keys & %i[category_caption category_name show_possible_categories]).empty?

            values = {}
            value_definition.each { |value|
              #raise unless value.is_a?(Integer) || value.is_a?(String) || value.is_a?(Symbol)
              value_key = value.to_s.strip.downcase
              raise if !key_valid?(value_key) || values.has_key?(value_key) || value_key == alternative_value_key
              values[value_key] = value
            }
            definition[:value_definition] = values

            if opts.has_key?(:allow_value_exclusion)
              allow_value_exclusion = opts[:allow_value_exclusion]
              raise unless allow_value_exclusion.is_a?(FalseClass) || allow_value_exclusion.is_a?(TrueClass)
              definition[:allow_value_exclusion] = allow_value_exclusion
            end
          elsif value_definition.is_a?(Hash)
            raise unless opts.has_key?(:category_caption)

            values = {}
            value_definition.each { |category, category_value_definition|
              #raise unless category.is_a?(Integer) || category.is_a?(String) || category.is_a?(Symbol)
              category_key = category.to_s.strip.downcase
              raise if !key_valid?(category_key) || values.has_key?(category_key)

              raise unless category_value_definition.is_a?(Array)
              category_values = {}
              category_value_definition.each { |value|
                #raise unless value.is_a?(Integer) || value.is_a?(String) || value.is_a?(Symbol)
                value_key = value.to_s.strip.downcase
                raise if !key_valid?(value_key) || category_values.has_key?(value_key)
                category_values[value_key] = value
              }

              values[category_key] = [category, category_values]
            }
            definition[:value_definition] = values

            category_caption = opts[:category_caption]
            raise unless category_caption.is_a?(String)
            category_caption = category_caption.strip
            raise if category_caption.empty?
            definition[:category_caption] = category_caption

            if opts.has_key?(:category_name)
              category_name = opts[:category_name]
              raise unless category_name.is_a?(String)
              category_name = category_name.strip
              raise if category_name.empty?
              definition[:category_name] = category_name
            else
              definition[:category_name] = category_caption + ' name'
            end

            if opts.has_key?(:show_possible_categories)
              show_possible_categories = opts[:show_possible_categories]
              raise unless [:multi_line, :no, :single_line].include?(show_possible_categories)
              definition[:show_possible_categories] = show_possible_categories
            else
              definition[:show_possible_categories] = :single_line
            end
          else
            raise unless (opts_keys & %i[category_caption category_name on_select show_possible_categories show_possible_values]).empty?
            definition[:value_definition] = value_definition
          end

          if opts.has_key?(:default)
            definition[:default] = opts[:default]
          end

          if opts.has_key?(:default_value)
            definition[:default_value] = opts[:default_value]
          end

          if opts.has_key?(:on_select)
            on_select = opts[:on_select]
            raise unless on_select.lambda?
            definition[:on_select] = on_select
            # check lambda parameters
          end

          if opts.has_key?(:show_possible_values)
            show_possible_values = opts[:show_possible_values]
            raise unless %i[multi_line no single_line].include?(show_possible_values)
            definition[:show_possible_values] = show_possible_values
          else
            definition[:show_possible_values] = :single_line
          end

          if opts.has_key?(:value_name)
            value_name = opts[:value_name]
            raise unless value_name.is_a?(String)
            value_name = value_name.strip
            raise if value_name.empty?
            definition[:value_name] = value_name
          else
            if value_definition_kind == :flags_of
              definition[:value_name] = 'value'
            else
              definition[:value_name] = name.to_s + ' name'
            end
          end
        end

        definitions[option_key] = definition
      rescue
        puts "Invalid definition of the option '#{name}'"
        raise
      end
      
      nil
    end

    def get_option_caption(definition)
      s = "'#{definition[:name]}'"
      s << " (#{definition[:caption]})" if definition[:caption]
      s
    end

    def key_valid?(key)
      !(key.empty? || key =~ /[,;]/ || key[0] == '-')
    end
    
    def parse_internal(definitions, args)
      options = {}
      args.each { |arg|
        s = arg.strip
        if s.empty?
          abort('There is an empty argument in the command line.') end
        unless %w[- /].include?(s[0]) && s.size > 1
          abort("The string '#{s}' is not an option.#{usage_rules}") end
        if index = s.index(':')
          option = s[1...index].strip
          value = s[index + 1..-1].lstrip.encode!('utf-8')
        else
          option = s[1..-1].lstrip
          value = ''
        end
        option_key = option.downcase
        definition = definitions[option_key]
        unless definition
          abort("Unknown option '#{option}'.#{usage_rules}") end
        option = definition[:name]
        option_caption = get_option_caption(definition)
        if value.empty? && s.include?(':')
          abort("An empty value was specified for the option #{option_caption}.") end
        if value.empty? && definition[:value_required] == :has_value
          abort("A value was not specified for the option #{option_caption}.#{usage_rules}") end
        if !value.empty? && definition[:value_required] == :flag
          abort("A value was specified for the option #{option_caption}.#{usage_rules}") end

        if (value_definition_kind = definition[:value_definition_kind])
          value_definition = definition[:value_definition]
          value = if value_definition.nil? || value_definition.is_a?(Regexp)
            parse_value_multiple_of(definition, value)
          elsif value_definition.values[0].is_a?(Array)
            parse_value_categorized_multiple_of_items(definition, value)
          else
            if value_definition_kind == :one_of
              parse_value_one_of_items(definition, value)
            else
              parse_value_multiple_of_items(definition, value)
            end
          end
        elsif definition[:value_required] == :flag
          value = true
        elsif value.empty?
          value = definition[:default_value] if definition.has_key?(:default_value)
        elsif !value.empty? && (value_pattern = definition[:value_pattern]) && value !~ value_pattern
          s = "Incorrect #{definition[:value_name]} '#{value}' in the option #{option_caption}."
          s << " Type #{File.basename($0)} to see the possible value." if definition[:show_possible_value]
          abort(s)
        end

        if options.has_key?(option)
          abort("The option #{option_caption} is duplicated.") end
        options[option] = value
      }

      definitions.each_value { |definition|
        option = definition[:name]
        next if options.has_key?(option)

        if definition[:required]
          abort("The option #{get_option_caption(definition)} was not specified.#{usage_rules}")
        end

        if definition[:value_required] == :flag
          options[option] = false
        elsif definition[:value_definition_kind] == :flags_of
          options[option] = (definition[:value_definition].values.map { |item| [item, false] }).to_h
        else
          options[option] = definition[:default] if definition.has_key?(:default)
        end
      }

      options
    end

    def parse_value_categorized_multiple_of_items(definition, value)
      return definition[:default_value] if value.empty?

      if definition.has_key?(:alternative_value)
        alternative_value = definition[:alternative_value]
        return alternative_value if alternative_value.to_s.strip.downcase == value.downcase
      end

      option = definition[:name]
      option_caption = get_option_caption(definition)
      value_definition = definition[:value_definition]
      result = {}
      value.split(';', -1).each { |s|
        s.strip!
        unless s.count(',') == 1
          abort("Incorrect value '#{value}' in the option #{option_caption}.#{usage_rules}") end

        if s[0] == ','
          abort("An empty #{definition[:category_name]} in the option #{option_caption}.#{usage_rules}") end
        category = s[0...s.index(',')].rstrip
        category_key = category.downcase
        unless value_definition.has_key?(category_key)
          show_unknown_value_error(definition, nil, category) end
        category = value_definition[category_key][0]
        if result.has_key?(category)
          abort("The #{definition[:category_name]} '#{category}' is duplicated in the option #{option_caption}.") end
        definition[:on_select].call(category, nil) if definition[:on_select]

        category_value_definition = value_definition[category_key][1]
        raise if category_value_definition.empty?
        category_value = s[s.index(',') + 1..-1].lstrip
        if category_value.empty?
          abort("An empty #{definition[:value_name]} for the #{definition[:category_caption]} '#{category}' in the option #{option_caption}.#{usage_rules}") end
        category_value_key = category_value.downcase
        unless category_value_definition.has_key?(category_value_key)
          show_unknown_value_error(definition, category_value, category_key) end
        category_value = category_value_definition[category_value_key]
        definition[:on_select].call(category, category_value) if definition[:on_select]

        result[category] = category_value
      }

      # sort hash?

      result
    end

    def parse_value_multiple_of(definition, value)
      return definition[:default_value] if value.empty?

      if definition.has_key?(:alternative_value)
        alternative_value = definition[:alternative_value]
        alternative_value_key = alternative_value.to_s.strip.downcase
        return alternative_value if alternative_value_key == value.downcase
      end

      values = {}
      option_caption = get_option_caption(definition)
      value_definition = definition[:value_definition]
      value.split(',', -1).each { |s|
        s.strip!
        abort("An empty #{definition[:value_name]} in the option #{option_caption}.") if s.empty?
        value_key = s.downcase
        if value_key == alternative_value_key
          abort("The #{definition[:value_name]} '#{alternative_value}' (if is supplied) can be the only value in the option #{option_caption}.#{usage_rules}") end
        if value_definition.is_a?(Regexp) && s !~ value_definition
          abort("Incorrect #{definition[:value_name]} '#{s}' in the option #{option_caption}.#{usage_rules}")
        end
        if values.has_key?(value_key)
          abort("The #{definition[:value_name]} '#{values[value_key]}' is duplicated in the option #{option_caption}.") end
        values[value_key] = s
      }

      values.values
    end

    def parse_value_multiple_of_items(definition, value)
      return definition[:default_value] if value.empty?

      if definition.has_key?(:alternative_value)
        alternative_value = definition[:alternative_value]
        alternative_value_key = alternative_value.to_s.strip.downcase
        return alternative_value if alternative_value_key == value.downcase
      end

      is_value_exclusion_allowed = definition[:allow_value_exclusion]
      on_select = definition[:on_select]
      option_caption = get_option_caption(definition)
      value_definition = definition[:value_definition]
      value_definition_kind = definition[:value_definition_kind]
      value_keys = []

      if value == '-'
        abort("Incorrect value '#{value}' in the option #{option_caption}.#{usage_rules}") end
      count = value.count('-')
      if count > 1 || count == 1 && !(is_value_exclusion_allowed && value[0] == '-')
        abort("Incorrect value '#{value}' in the option #{option_caption}.#{usage_rules}") end
      is_value_exclusion = value[0] == '-'

      (is_value_exclusion ? value[1..-1] : value).split(',', -1).each { |s|
        s.strip!
        if s.empty?
          abort("An empty #{definition[:value_name]} in the option #{option_caption}.") end
        value_key = s.downcase
        if value_key == alternative_value_key
          if is_value_exclusion
            abort("Incorrect value '#{value}' in the option #{option_caption}.#{usage_rules}") end
          abort("The #{definition[:value_name]} '#{alternative_value}' (if is supplied) can be the only value in the option #{option_caption}.#{usage_rules}")
        end
        v = value_definition[value_key]
        unless v
          show_unknown_value_error(definition, s) end
        if value_keys.include?(value_key)
          abort("The #{definition[:value_name]} '#{v}' is duplicated in the option #{option_caption}.") end
        value_keys << value_key
        if on_select && !is_value_exclusion
          if is_value_exclusion_allowed
            on_select.call(v, false)
          else
            on_select.call(v)
          end
        end
      }

      if value_definition_kind == :multiple_of
        value = []
        value_definition.each_key { |item|
          if is_value_exclusion
            next if value_keys.include?(item)
            v = value_definition[item]
            value << v if on_select.call(v, true)
          else
            value << value_definition[item] if value_keys.include?(item)
          end
        }

        if is_value_exclusion && value.empty?
          value = on_select.call(nil, true)
        end
      else
        value = {}
        value_definition.each_key { |item|
          value[value_definition[item]] = value_keys.include?(item)
        }
      end

      value
    end

    def parse_value_one_of_items(definition, value)
      return definition[:default_value] if value.empty?

      result = definition[:value_definition][value.downcase]
      unless result
        show_unknown_value_error(definition, value) end
      definition[:on_select].call(result) if definition[:on_select]
      result
    end

    def show_unknown_value_error(definition, value, category_key = nil)
      value_definition = definition[:value_definition]
      option_caption = get_option_caption(definition)

      if category_key
        if value
          category = value_definition[category_key][0]
          s = "Unknown #{definition[:value_name]} '#{value}' for the #{definition[:category_caption]} '#{category}' in the option #{option_caption}. "
          possible_values = value_definition[category_key][1].values
        else
          s = "Unknown #{definition[:category_name]} '#{category_key}' in the option #{option_caption}. "
          possible_values = value_definition.values.map { |item| item[0] }
        end
      else
        s = "Unknown #{definition[:value_name]} '#{value}' in the option #{option_caption}. "
        possible_values = value_definition.values
      end

      show_possible_values = definition[value ? :show_possible_values : :show_possible_categories]
      case show_possible_values
        when :multi_line
          s << 'The possible values are' + (possible_values.map { |item| "\n    #{item}" }).join('')
        when :no
          s << "Type #{File.basename($0)} to see possible values."
        when :single_line
          if possible_values.size == 1
            s << "The possible value is '#{possible_values[0]}'."
          else
            s << 'The possible values are '
            s << (possible_values[0..-2].map { |item| "'#{item}'" }).join(', ') + " and '" + possible_values.last.to_s + "'."
          end
      end
      abort(s)
    end

    def usage_rules
      " Type #{File.basename($0)} to see the usage rules."
    end
  end
end
# :enddoc:
# *required* specifies whether the option is required in command line. Possible values are +:optional+ and +:required+. If a required option was not supplied
# then +abort+ will be used to terminate script execution.
#
# *value_required* specifies whether the option requires a value. Possible values are
# * +:flag+ - special kind of option. The only allowed option definitions are
#
#     opt :i, :optional, :flag
#     opt :i, :optional, :flag, caption: 'install'
#
#     ''   #=> {i: false}
#     '-i' #=> {i: true}
#
#   +:caption+ in +opts+ defines caption of the option in error messages:
#
#     opt :i, :optional, :flag
#     '-i -i' #=> The option 'i' is duplicated.
#
#     opt :i, :optional, :flag, caption: 'install'
#     '-i -i' #=> The option 'i' (install) is duplicated.
#
# * +:has_value+ - the option requires a value:
#
#     opt :i, :optional, :has_value
#
#     ''      #=> {}
#     '-i:r1' #=> {i: 'r1'}
#     '-i'    #=> A value was not specified for the option 'i'. Type ... to see the usage rules.
#
# Examples:
#
#   opt :i, :optional, :flag
#
#   opt :p, :optional, :has_value, caption: 'platforms',
#     multiple_of: %i[D7 XE6 D10], allow_value_exclusion: true, alternative_value: :all, value_name: 'platform name',
#     on_select: lambda { |platform, is_after_exclusion|
#       if platform
#         return platform.installed? if is_after_exclusion
#         check_platform(platform)
#       else
#         abort("No installed platforms to perform actions after platform exclusion in the option 'p' (platforms).")
#       end
#     }
#
