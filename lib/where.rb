# A little Ruby module for finding the source location where class and methods are defined.
# https://gist.github.com/wtaysom/1236979

module Where
  #== Example
  # 
  #   Where.is_class Post, of: 'app/models'
  # 
  class <<self
    def is_class(klass, opts={})
      methods = defined_methods(klass)
      file_groups = methods.group_by{|sl| sl[0]}
      file_counts = file_groups.map do |file, sls|
        lines = sls.map{|sl| sl[1]}
        count = lines.size
        line = lines.min
        {file: file, count: count, line: line}
      end
      file_counts.sort_by!{|fc| fc[:count]}
    
      if opts[:of].present?
        path_expand = joins_path(opts[:of])
        return File.expand_path("../../spec/spec_helper.rb", __FILE__) unless !!path_expand
        pattern = Regexp.new "^#{path_expand}/.*"
        matches = file_counts.select do |fc| 
          !!fc[:file][pattern] 
        end
        return matches.first[:file] if matches.first.present?
      end
    
      source_locations = file_counts.map{|fc| [fc[:file], fc[:line]]}
      source_locations
    end
  
  private
    def joins_path(of)
      Rails.root.join(of).to_s
      path_expand
    rescue NameError
      return false
    end    
    
    def source_location(method)
      method.source_location || (
        method.to_s =~ /: (.*)>/
        $1
      )
    end
  
    def defined_methods(klass)
      methods = klass.methods(false).map{|m| klass.method(m)} +
        klass.instance_methods(false).map{|m| klass.instance_method(m)}
      methods.map!(&:source_location)
      methods.compact!
      methods
    end
  end
end

def where_is(klass, method = nil)
  Where.edit(if method
    begin
      Where.is_instance_method(klass, method)
    rescue NameError
      Where.is_method(klass, method)
    end
  else
    Where.is_class_primarily(klass)
  end)
end