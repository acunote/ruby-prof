
module RubyProf
  # Generate profiling information in calltree format
  # for use by kcachegrind and similar tools.

  class CallTreePrinter  < AbstractPrinter
    # Specify print options.
    #
    # options - Hash table
    #   :min_percent - Number 0 to 100 that specifes the minimum
    #                  %self (the methods self time divided by the
    #                  overall total time) that a method must take
    #                  for it to be printed out in the report.
    #                  Default value is 0.
    #
    #   :print_file  - True or false. Specifies if a method's source
    #                  file should be printed.  Default value if false.
    #
    def print(output = STDOUT, options = {})
      @output = output
      setup_options(options)

      # add a header - this information is somewhat arbitrary
      @output << "events: "
      case RubyProf.measure_mode
        when RubyProf::PROCESS_TIME
          @value_scale = RubyProf::CLOCKS_PER_SEC;
          @output << 'process_time'
        when RubyProf::WALL_TIME
          @value_scale = 1_000_000
          @output << 'wall_time'
        when RubyProf.const_defined?(:CPU_TIME) && RubyProf::CPU_TIME
          @value_scale = RubyProf.cpu_frequency
          @output << 'cpu_time'
        when RubyProf.const_defined?(:ALLOCATIONS) && RubyProf::ALLOCATIONS
          @value_scale = 1
          @output << 'allocations'
        when RubyProf.const_defined?(:MEMORY) && RubyProf::MEMORY
          @value_scale = 1
          @output << 'memory'
        when RubyProf.const_defined?(:GC_RUNS) && RubyProf::GC_RUNS
          @value_scale = 1
          @output << 'gc_runs'
        when RubyProf.const_defined?(:GC_TIME) && RubyProf::GC_TIME
          @value_scale = 1000000
          @output << 'gc_time'
        else
          raise "Unknown measure mode: #{RubyProf.measure_mode}"
      end
      @output << "\n\n"

      print_threads
    end

    def print_threads
      @result.threads.each do |thread_id, methods|
        print_methods(thread_id, methods)
      end
    end

    def convert(value)
      (value * @value_scale).round
    end

    def file(method)
      File.expand_path(method.source_file)
    end

    def print_methods(thread_id, methods)
      methods.reverse_each do |method|
        # Print out the file and method name
        @output << "fl=#{file(method)}\n"
        @output << "fn=#{method_name(method)}\n"

        # Now print out the function line number and its self time
        @output << "#{method.line} #{convert(method.self_time)}\n"

        # Now print out all the children methods
        method.children.each do |callee|
          @output << "cfl=#{file(callee.target)}\n"
          @output << "cfn=#{method_name(callee.target)}\n"
          @output << "calls=#{callee.called} #{callee.line}\n"

          # Print out total times here!
          @output << "#{callee.line} #{convert(callee.total_time)}\n"
        end
      @output << "\n"
      end
    end #end print_methods
  end # end class

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
