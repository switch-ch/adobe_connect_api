#Result objects are returned by some of the convenience methods to make the
#resulting values more accessible. The status attribute returns the status/@code field
#and the rows attribute is an array of hashes with the values of the resulting
#rows (or quotas etc.)

class Result

  attr_reader :status
  attr_reader :rows

  def initialize (status, rows)
    @status = status
    @rows = []
    if rows != nil
      rows.each do |row|
        hash = {}
        row.each_pair do |name, val|
          if val.is_a?(Array)
            hash[name] = val[0]
          else
            hash[name] = val
          end
        end
        @rows.push hash
      end
    end
  end

end
