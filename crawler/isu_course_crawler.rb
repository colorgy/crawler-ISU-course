require 'crawler_rocks'
require 'json'
require 'iconv'
require 'pry'

require 'thread'
require 'thwait'

class IShouUniversityCrawler

  PERIODS = {
    "1" => 1,
    "2" => 2,
    "3" => 3,
    "4" => 4,
    "5" => 5,
    "6" => 6,
    "7" => 7,
    "8" => 8,
    "9" => 9,
    "A" => 10,
    "B" => 11,
    "C" => 12,
    "D" => 13,
  }


  def initialize year: nil, term: nil, update_progress: nil, after_each: nil

    @year = year
    @term = term
    @update_progress_proc = update_progress
    @after_each_proc = after_each

    @query_url = %x(curl -s 'http://netreg.isu.edu.tw/wapp/wapp_sha/wap_s140000_bilingual.asp' --compressed)
    @ic = Iconv.new('utf-8//IGNORE//translit', 'big5')
  end

  def courses
    @courses = []

    doc = Nokogiri::HTML(@ic.iconv(@query_url))
    majr_option = doc.css('table')[1].css('tr')[2].css('option')

    # 年級 (1~15)
    grade_beg = 1
    grade_end = 9
    # 部別
    divi_A="A"
    divi_M="M"
    divi_I="I"
    divi_D="D"
    divi_B="B"
    divi_G="G"
    divi_T="T"
    divi_F="T"

    threads = []

    (0..majr_option.count - 2).each do |i|
      sleep(1) until (
        threads.delete_if { |t| !t.status };  # remove dead (ended) threads
        threads.count < (ENV['MAX_THREADS'] || 20)
      )
      threads << Thread.new do
        data = []
        # 系所
        majr_no = majr_option[i].text[0..1]
        print "#{majr_no}\n"
        # binding.pry if majr_no == '10'
        r  = %x(curl -s 'http://netreg.isu.edu.tw/wapp/wapp_sha/wap_s140001.asp' --data 'lange_sel=zh_TW&qry_setyear=#{@year-1911}&qry_setterm=#{@term}&grade_beg=#{grade_beg}&grade_end=#{grade_end}&majr_no=#{majr_no}&divi_A=#{divi_A}&divi_M=#{divi_M}&divi_I=#{divi_I}&divi_D=#{divi_D}&divi_B=#{divi_B}&divi_G=#{divi_G}&divi_T=#{divi_T}&divi_F=#{divi_F}&cr_code=&cr_name=&yepg_sel=+&crdnum_beg=0&crdnum_end=6&apt_code=+&submit1=%B0e%A5X' --compressed)
        doc = Nokogiri::HTML(@ic.iconv(r))

        if doc.css('table').count < 1
          next
        end

        (2..doc.css('table')[1].css('tr').count - 1).each do |j|
          (1..doc.css('table')[1].css('tr')[j].css('td').count - 1).each do |k|

            if doc.css('table')[1].css('tr')[j].css('td')[k].text == ""
              next
            end

            data[k] = doc.css('table')[1].css('tr')[j].css('td')[k].content
          end

          code = "#{@year}-#{@term}-#{data[1].strip}"

          course_days = []
          course_periods = []
          course_locations = []
          data[9..15].each_with_index do |data, index|
            data.match(/[#{PERIODS.keys.join}]+/).to_s.split('').each {|p|
              course_days << index+1
              course_periods << PERIODS[p]
              course_locations << data[8]
            }
          end

          course = {
            year: @year,
            term: @term,
            department_code: majr_option[i].text[0..1],  # 系所代碼
            department: data[3].strip,    # 開課系級
            general_code: data[1].strip,    # 課程代號
            code: code,
            name: data[2].strip,    # 課程名稱
            credits: data[4].to_i,   # 學分數
            required: data[5].include?('必'),    # 修別(必選修)
            people_limit: data[6],    # 限制選修人數
            people: data[7].to_i,    # 修課人數
            day_1: course_days[0],
            day_2: course_days[1],
            day_3: course_days[2],
            day_4: course_days[3],
            day_5: course_days[4],
            day_6: course_days[5],
            day_7: course_days[6],
            day_8: course_days[7],
            day_9: course_days[8],
            period_1: course_periods[0],
            period_2: course_periods[1],
            period_3: course_periods[2],
            period_4: course_periods[3],
            period_5: course_periods[4],
            period_6: course_periods[5],
            period_7: course_periods[6],
            period_8: course_periods[7],
            period_9: course_periods[8],
            location_1: course_locations[0],
            location_2: course_locations[1],
            location_3: course_locations[2],
            location_4: course_locations[3],
            location_5: course_locations[4],
            location_6: course_locations[5],
            location_7: course_locations[6],
            location_8: course_locations[7],
            location_9: course_locations[8],
            notes: data[16],    # 備註說明
          }

          @after_each_proc.call(course: course) if @after_each_proc

          @courses << course
        end
      end # end Thread
    end
    ThreadsWait.all_waits(*threads)

    @courses
  end
end

# crawler = IShouUniversityCrawler.new(year: 2015, term: 1)
# File.write('courses.json', JSON.pretty_generate(crawler.courses()))
