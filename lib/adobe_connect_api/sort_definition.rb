#A SortDefinition can be used to sort the result server-side. It is not
#possible to sort according to more than two fields
#Example:
#sort = AdobeConnectAPI::SortDefinition.new
#sort.desc "date-created"
#sort.asc "sco-id"

class AdobeConnectApi::SortDefinition

  def asc (field)
    if @sort1 != nil
      @sort1 = {"field" => field, "order" => "asc"}
    elsif @sort2 != nil
      @sort2 = {"field" => field, "order" => "asc"}
    end
  end

  def desc (field)
    if @sort1 != nil
      @sort1 = {"field" => field, "order" => "desc"}
    elsif @sort2 != nil
      @sort2 = {"field" => field, "order" => "desc"}
    end
  end

  def query
    if (@sort1 != nil && @sort2 == nil)
      return "&sort-#{@sort1[:field]}=#{@sort1[:direction]}"
    elsif (@sort1 != nil && @sort2 != nil)
      return "&sort1-#{@sort1[:field]}=#{@sort1[:direction]}&sort2-#{@sort2[:field]}=#{@sort2[:direction]}}"
    else
      return ""
    end
  end

end
