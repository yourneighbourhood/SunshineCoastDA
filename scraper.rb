require 'scraperwiki'
require 'mechanize'
require 'json'


case ENV['MORPH_PERIOD']
when 'thismonth'
  period = 'This Month'
  startDate = ((Date.today) - (Date.today.mday) + 1)
  endDate = (Date.today >> 1) - (Date.today.mday)
when 'lastmonth'
  period = 'Last Month'
  startDate = ((Date.today << 1) - (Date.today.mday) + 1)
  endDate = (Date.today) - (Date.today.mday)
else
  period = 'Last 14 Days'
  startDate = (Date.today - 14)
  endDate = Date.today
end
puts "Getting '" + period + "' data, changable via MORPH_PERIOD environment"

url = 'https://developmenti.sunshinecoast.qld.gov.au/Home/ApplicationTileSearch'
payload = '{"Progress":"all","StartDateUnixEpochNumber":1549285200000,"EndDateUnixEpochNumber":1551963599999,"DateRangeField":"submitted","DateRangeDescriptor":"Last 30 Days","LotPlan":null,"LandNumber":null,"DANumber":null,"BANumber":null,"PlumbNumber":null,"IncludeDA":true,"IncludeBA":false,"IncludePlumb":false,"LocalityId":null,"DivisionId":null,"ApplicationTypeId":null,"SubCategoryUseId":null,"ShowCode":true,"ShowImpact":true,"ShowOther":true,"PagingStartIndex":0,"MaxRecords":200,"Boundary":null,"ViewPort":{"BoundaryType":"POLYGON","GeometryPropertyName":"geom_point","Boundary":[[{"Lat":-27.07045886388122,"Lng":151.12321057707288},{"Lat":-27.07045886388122,"Lng":154.78195825010755},{"Lat":-26.240905814925092,"Lng":154.78195825010755},{"Lat":-26.240905814925092,"Lng":151.12321057707288},{"Lat":-27.07045886388122,"Lng":151.12321057707288}]]},"IncludeAroundMe":false,"SortField":"submitted","SortAscending":true,"BBox":null,"PixelWidth":800,"PixelHeight":800}'

## Update JSON fields
json_hash = JSON.parse(payload)
json_hash['StartDateUnixEpochNumber'] = startDate.to_time.to_i * 1000
json_hash['EndDateUnixEpochNumber']   = endDate.to_time.to_i * 1000
json_hash['DateRangeDescriptor']      = period


agent = Mechanize.new
page = agent.post url, json_hash.to_json, {'Content-Type' => 'application/json'}

page.search('div.application-tile').each do |div|
  matches = div.search('div.description-trunc').inner_text.split('Description: ')[1].split(' - ', 2)

  matches.each.with_index do |match, index|
    matches[index] = match.strip
  end

  ## clean up address a little if possible
  if ( matches[0] == 'FASTTRACK'  ||
       matches[0] == 'FAST TRACK' ||
       matches[0] == 'FASTRACK'   ||
       matches[0] == 'WITHDRAWN'     )
    matches = div.search('div.description-trunc').inner_text.split('Description: ')[1].split(' - ', 3)
    matches.delete_at(0)
  end

  if ( matches.count >= 2 )
    record = {
      'council_reference' => div.search('div')[0].inner_text.split('Application Number: ')[1].strip,
      'address' => matches[0].strip,
      'description' => matches[1].strip,
      'info_url' => 'https://developmenti.sunshinecoast.qld.gov.au',
      'comment_url' => 'mail@sunshinecoast.qld.gov.au',
      'date_scraped' => Date.today,
      'date_received' => Date.strptime( div.search('div.application-tile-property span.date-number').attr('data-date-number').value.to_s, '%Q' ) + 1
    }

    if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
      puts "Saving record " + record['council_reference'] + ", " + record['address']
#       puts record
      ScraperWiki.save_sqlite(['council_reference'], record)
    else
      puts "Skipping already saved record " + record['council_reference']
    end
  else
    puts "error to parse council_reference's address: " + div.search('div')[0].inner_text.split('Application Number: ')[1].strip
  end
end
