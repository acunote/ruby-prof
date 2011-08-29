
module RubyProf

  class GraphPrinterWithoutAggregation < GraphPrinter
    private
    def print_methods(thread_id, methods)
        # Sort methods from longest to shortest total time
        methods = methods.sort

        toplevel = methods.last
        total_time = toplevel.total_time
        total_time = 0.01 if total_time == 0

        print_heading(thread_id)

        # Print each method in total time order
        methods.reverse_each do |method|
            total_percentage = (method.total_time/total_time) * 100
            self_percentage = (method.self_time/total_time) * 100

            next if total_percentage < min_percent

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
               @output << "-" * 80 << "\n"
               print_parent(parent, method) if parent

               # 1 is for % sign
               @output << sprintf("%#{PERCENTAGE_WIDTH-1}.2f\%", total_percentage)
               @output << sprintf("%#{PERCENTAGE_WIDTH-1}.2f\%", self_percentage)
               @output << sprintf("%#{TIME_WIDTH}.2f", method.total_time)
               @output << sprintf("%#{TIME_WIDTH}.2f", method.self_time)
               @output << sprintf("%#{TIME_WIDTH}.2f", method.wait_time)
               @output << sprintf("%#{TIME_WIDTH}.2f", method.children_time)
               @output << sprintf("%#{CALL_WIDTH}i", method.called)
               @output << sprintf("     %s", method_name(method))
               if print_file
                   @output << sprintf("  %s:%s", method.source_file, method.line)
               end
               @output << "\n"

               print_children(children)
            end
        end
    end

    def print_parent(parent, method)
        @output << " " * 2 * PERCENTAGE_WIDTH
        @output << sprintf("%#{TIME_WIDTH}.2f", parent.total_time)
        @output << sprintf("%#{TIME_WIDTH}.2f", parent.self_time)
        @output << sprintf("%#{TIME_WIDTH}.2f", parent.wait_time)
        @output << sprintf("%#{TIME_WIDTH}.2f", parent.children_time)

        call_called = "#{parent.called}/#{method.called}"
        @output << sprintf("%#{CALL_WIDTH}s", call_called)
        @output << sprintf("     %s", parent.parent.target.full_name)
        @output << "\n"
    end

    def print_children(children)
      children.each do |child|
        @output << " " * 2 * PERCENTAGE_WIDTH

        @output << sprintf("%#{TIME_WIDTH}.2f", child.total_time)
        @output << sprintf("%#{TIME_WIDTH}.2f", child.self_time)
        @output << sprintf("%#{TIME_WIDTH}.2f", child.wait_time)
        @output << sprintf("%#{TIME_WIDTH}.2f", child.children_time)

        call_called = "#{child.called}/#{child.target.called}"
        @output << sprintf("%#{CALL_WIDTH}s", call_called)
        @output << sprintf("     %s", child.target.full_name)
        @output << "\n"
      end
    end

  end #end class
end

