
module RubyProf
  # Generate profiling information in calltree format
  # for use by kcachegrind and similar tools.

  class CallTreePrinterWithoutAggregation < CallTreePrinter
    def get_sequence_index(sequence)
        @seq_cache ||= Hash.new
        @seq_index ||= 1
        sequence_array = sequence.split("->")
        method_name = sequence_array.last
        sequence = sequence_array.count>1 ? sequence_array[0..sequence_array.count - 2].join("->") : "root"
        @seq_cache[method_name] = Hash.new unless @seq_cache.has_key?(method_name)
        @seq_cache[method_name][sequence] = @seq_cache[method_name].keys.count+1 unless @seq_cache[method_name].include?(sequence)
        @seq_cache[method_name][sequence]
    end

    def print_methods(thread_id, methods)
        methods.reverse_each do |method|
        parents = method.call_infos.map{|caller| caller if caller.parent}
        children = method.children
        call_tree = Hash.new
        parents.each do |parent|
            call_tree[parent] = Array.new
            if parent
                children.each do |child|
                   call_tree[parent] << child if child.call_sequence.include?(parent.call_sequence)
                end
            else
                call_tree[parent] = children
            end
        end

        call_tree.each do |parent, children|
            # Print out the file and method name
            @output << "fl=#{file(method)}\n"
            @output << (parent ? "fn=#{method.full_name}(#{get_sequence_index(parent.call_sequence)})\n" : "fn=#{method.full_name}\n")

            # Now print out the function line number and its self time
            @output << "#{method.line} #{convert(method.self_time)}\n"

            # Now print out all the children methods
            children.each do |callee|
                @output << "cfl=#{file(callee.target)}\n"
                @output << "cfn=#{callee.target.full_name}(#{get_sequence_index(callee.call_sequence)})\n"
                @output << "calls=#{callee.called} #{callee.line}\n"

                # Print out total times here!
                @output << "#{callee.line} #{convert(callee.total_time)}\n"
            end
            @output << "\n"
            end
        end
    end #end print_methods

  end #end class

end # end packages
