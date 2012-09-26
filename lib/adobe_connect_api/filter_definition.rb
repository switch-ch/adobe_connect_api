# A filter definition can be added to some actions to filter the results
# server-side. Example:
# filter = AdobeConnectAPI::FilterDefinition.new
# filter["sco-id"].greater_than 25
# filter["date-created"] <= Time.now

# TODO KG: rename to AdobeConnectAPI since the class is also named API
class AdobeConnectApi::FilterDefinition
  attr_accessor :rows
  attr_accessor :start
  attr_accessor :is_member

  def initialize
    @fields = Hash.new
  end

  def [](field_name)
    field = @fields[field_name]
    if field == nil
      field = AdobeConnectApi::FilterDefinition::Field.new(field_name)
      @fields[field_name] = field
    end
    return field
  end

  def query
    string = ""

    if @rows != nil
      string += "&filter-rows=" + "#{@rows}"
    end
    if @start != nil
      string += "&filter-start=" + "#{@start}"
    end
    if @is_member != nil
      if @is_member
        string += "&filter-is-member=true"
      else
        string += "&filter-is-member=false"
      end
    end

    @fields.each_pair do |name, f|
      string += f.query
    end
    return string
  end

  class Field
    def matches (value)
      @matches = value
    end

    def greater_than (value)
      @greater_than = value
    end

    def lesser_than (value)
      @lesser_than = value
    end

    def like (value)
      @like = value
    end

    def greater_than_or_equals (value)
      @greater_than_or_equals = value
    end

    def lesser_than_or_equals (value)
      @lesser_than_or_equals = value
    end

    def excluding (value)
      @excluding = value
    end

    def == (value)
      @matches = value
    end

    def > (value)
      @greater_than = value
    end

    def < (value)
      @lesser_than = value
    end

    def >= (value)
      @greater_than_or_equals = value
    end

    def <= (value)
      @lesser_than_or_equals = value
    end

    def initialize (name)
      @name = name
    end

    def query
      query = ""
      if @matches != nil
        query += "&filter-" + @name + "=" + CGI.escape("#{@matches}")
      end
      if @greater_than != nil
        query += "&filter-gt-" + @name + "=" + CGI.escape("#{@greater_than}")
      end
      if @lesser_than != nil
        query += "&filter-lt-" + @name + "=" + CGI.escape("#{@lesser_than}")
      end
      if @like != nil
        query += "&filter-like-" + @name + "=" + CGI.escape("#{@like}")
      end
      if @greater_than_or_equals != nil
        query += "&filter-gte-" + @name + "=" + CGI.escape("#{@greater_than_or_equals}")
      end
      if @lesser_than_or_equals != nil
        query += "&filter-lte-" + @name + "=" + CGI.escape("#{@lesser_than_or_equals}")
      end
      if @excluding != nil
        query += "&filter-out-" + @name + "=" + CGI.escape("#{@excluding}")
      end

      return query
    end
  end
end
