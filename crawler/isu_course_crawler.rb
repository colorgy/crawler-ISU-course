require 'crawler_rocks'
require 'json'
require 'iconv'
require 'pry'

class IShouUniversityCrawler

  def initialize year: nil, term: nil, update_progress: nil, after_each: nil

    @year = year-1911
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

    for i in 0..majr_option.count - 2
      data = []
      # 系所
      majr_no = majr_option[i].text[0..1]
      puts majr_no
      # binding.pry if majr_no == '10'
      r  = %x(curl -s 'http://netreg.isu.edu.tw/wapp/wapp_sha/wap_s140001.asp' --data 'lange_sel=zh_TW&qry_setyear=#{@year}&qry_setterm=#{@term}&grade_beg=#{grade_beg}&grade_end=#{grade_end}&majr_no=#{majr_no}&divi_A=#{divi_A}&divi_M=#{divi_M}&divi_I=#{divi_I}&divi_D=#{divi_D}&divi_B=#{divi_B}&divi_G=#{divi_G}&divi_T=#{divi_T}&divi_F=#{divi_F}&cr_code=&cr_name=&yepg_sel=+&crdnum_beg=0&crdnum_end=6&apt_code=+&submit1=%B0e%A5X' --compressed)
      doc = Nokogiri::HTML(@ic.iconv(r))

      if doc.css('table').count < 1
        next
      end

      for j in 2..doc.css('table')[1].css('tr').count - 1

        for k in 1..doc.css('table')[1].css('tr')[j].css('td').count - 1

          if doc.css('table')[1].css('tr')[j].css('td')[k].text == ""
            next
          end

          data[k] = doc.css('table')[1].css('tr')[j].css('td')[k].text
        end
        course = {
          year: @year,
          term: @term,
          department_code: majr_option[i].text[0..1],  # 系所代碼
          department: data[3],    # 開課系級
          general_code: data[1],    # 課程代號
          name: data[2],    # 課程名稱
          credits: data[4],   # 學分數
          required: data[5],    # 修別(必選修)
          people_limit: data[6],    # 限制選修人數
          people: data[7],    # 修課人數
          location: data[8],    # 教室位置
          day_1: data[9],   # 星期一的節次
          day_2: data[10],    # 星期二的節次
          day_3: data[11],    # 星期三的節次
          day_4: data[12],    # 星期四的節次
          day_5: data[13],    # 星期五的節次
          day_6: data[14],    # 星期六的節次
          day_7: data[15],    # 星期日的節次
          notes: data[16],    # 備註說明
        }

        @after_each_proc.call(course: course) if @after_each_proc

        @courses << course
      end

      # binding.pry
    end

    @courses
  end
end

# crawler = IShouUniversityCrawler.new(year: 2015, term: 1)
# File.write('courses.json', JSON.pretty_generate(crawler.courses()))
