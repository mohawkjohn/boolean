require "ruby-progressbar"


module Boolean
  class Combo
    def initialize left, op, right
      @left  = left
      @op    = @op
      @right = right
    end

    attr_reader :left, :op, :right
  end

  class BOPMatrix < OPMatrix
    # Create a new BOPMatrix, which stands for boolean orthogroup-phenotype matrix.
    #
    # It's created from another OPMatrix, but generates phenotypes by producing boolean combinations of the phenotypes
    # from the input matrix.
    #
    # operation is the type of boolean operation to use.
    def initialize opmatrix, operation
      associations = []
      @decipher = {} # convert from count to the boolean combination
      count = 0
      matrix_size = 0

      comb = Boolean.say_with_time("generating numeric combinations") do
        (0...opmatrix.shape[0]).to_a.combination(2)
      end

      Boolean.say_with_time("generating gene set combinations") do
        # Keep track of combinations so we can check for duplicates. This should save some time when we calculate
        # the distances later. This is the -reverse- of the associations array.
        uniques = {}

        # Generate ID combinations of all phenotypes
        comb.each do |pair|
          @decipher[count] ||= []
          left        = opmatrix.orthogroups_for_phenotype(pair[0])
          right       = opmatrix.orthogroups_for_phenotype(pair[1])

          # This is important. We ignore any phenotype with fewer than 2 orthogroups. When we build the distance matrix,
          # we may further reduce the search space.
          next if left.size < 2 || right.size < 2

          left_right  = left.send(operation, right)
          if left_right != left && left_right != right && left_right.size > 2 # no point in duplicating existing phenotypes
            combo_obj = Combo.new(pair[0], operation, pair[1])

            if uniques.has_key?(left_right.hash)
              @decipher[uniques[left_right.hash]] << combo_obj
            else
              uniques[left_right.hash] = count
              @decipher[count]    << combo_obj
              associations[count] = left_right
              count += 1
              matrix_size += left_right.size
            end
          end

          next unless operation == :-

          right_left = right.send(operation, left)
          if right_left != right && right_left != right && right_left.size > 2 && !uniques.include?(right_left.hash)
            combo_obj = Combo.new(pair[1], operation, pair[0])

            if uniques.has_key?(right_left.hash)
              @decipher[uniques[right_left.hash]] << combo_obj
            else
              uniques[right_left.hash] = count
              @decipher[count] << combo_obj
              associations[count] = right_left
              count += 1
              matrix_size += right_left.size
            end
          end
        end
      end

      # Create the data structure.
      Boolean.say_with_time("generating matrix data structure of capacity #{matrix_size}") do
        super(count, opmatrix.shape[1], matrix_size)
        self.extend(NMatrix::YaleFunctions)  # enable yale_vector_insert
        STDERR.puts "ija size=#{self.yale_ija.size}"
      end

      Boolean.say_with_time("filling matrix data structure") do
        i = 0
        bar = ProgressBar.create(:title => "Fill", :total => matrix_size)
        last_capacity = self.capacity

        begin
          j_array = associations.shift

          # Insert the whole array at once using a specially exposed helper function.
          self.yale_vector_insert(i, j_array.to_a, [1]*j_array.size)

          # The above is a faster way of doing the following:
          #j_array.each do |j|
          #  self[i,j] = 1
          #end

          i            += 1
          bar.progress += j_array.size
        end while i < count

        bar.finish
      end
    end

    attr_reader :decipher

  end
end