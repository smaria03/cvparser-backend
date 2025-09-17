module PdfParsing
  module ExperienceExtractor
    PERIOD_REGEX = /
  (
    (Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|
     Jul(y)?|Aug(ust)?|Sep(t)?(ember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?)
    [\s\/\-\.]?
    \d{4}
  |
    \d{1,2}[\/\-]\d{4}
  |
    \d{4}
  )
  \s*[\-]\s*
  (
    (Present|Prezent|Current)
  |
    (Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|
     Jul(y)?|Aug(ust)?|Sep(t)?(ember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?)
    [\s\/\-\.]?
    \d{4}
  |
    \d{1,2}[\/\-]\d{4}
  |
    \d{4}
  )
/ix.freeze
    def extract_experiences(sections)
      section_nodes = find_experience_nodes(sections)
      return [] if section_nodes.empty?

      parse_experience_nodes(section_nodes)
    end

    def extract_current_job(sections)
      experiences = extract_experiences(sections)
      experiences.find do |exp|
        normalized = normalize_period_text(exp[:period]).downcase
        normalized.match?(/present|prezent|current/)
      end
    end

    def calculate_total_experience_years(sections)
      experiences = extract_experiences(sections)
      total_months = experiences.sum { |exp| months_for_period(exp[:period]) }

      years = total_months / 12
      months = total_months % 12
      "#{years}.#{months}y"
    end

    private

    def find_experience_nodes(sections)
      section_hint = sections[:section_hint]
      return [] unless section_hint

      section = sections[:section_blocks].find do |s|
        s[:title].strip.downcase == section_hint[:text].strip.downcase
      end

      section ? section[:text_nodes] : []
    end

    def parse_experience_nodes(nodes)
      lines_before = lines_before_period(nodes)

      nodes.each_with_index.with_object([]) do |(node, idx), experiences|
        next unless period_line?(node[:text])

        period, job_details = extract_period_and_job_details(nodes, node, idx, lines_before)
        next if job_details.blank?

        experiences << { job_details: job_details, period: period }
      end
    end

    def extract_period_and_job_details(nodes, node, idx, lines_before)
      text = normalize_period_text(node[:text])
      match = text.match(PERIOD_REGEX)
      return [nil, nil] unless match

      period = match[0]
      inline_job = text.sub(period, '').strip.gsub(/[|\-–]+$/, '').strip
      job_lines = nodes[[idx - lines_before, 0].max...idx]
                  .pluck(:text)
                  .compact_blank
                  .join(', ')
      job_details = [job_lines, inline_job].compact_blank.join(', ')

      job_details = job_details
                .gsub(/[\/\-\|•]/, '')
                .gsub(', ,', ',')
                .gsub('  ', ' ')
                .strip
                .sub(/,\z/, '')

      [period, job_details]
    end

    def lines_before_period(nodes)
      index = nodes.find_index { |n| period_line?(n[:text]) }
      return 2 if index.nil? || index < 1

      index
    end

    def parse_date_string(date_str)
      return Time.zone.today if date_str.downcase.match?(/present|prezent|current/)
      return Date.new(date_str.to_i, 1, 1) if date_str.strip =~ /^\d{4}$/

      begin
        Date.parse(date_str)
      rescue StandardError
        nil
      end
    end

    def months_for_period(period)
      return 0 unless period =~ PERIOD_REGEX

      from_str, to_str = normalize_period_text(period).split(/-+/).map(&:strip)
      from_date = parse_date_string(from_str)
      to_date = parse_date_string(to_str) || Time.zone.today

      return 0 unless from_date

      months_between(from_date, to_date)
    end

    def months_between(from_date, to_date)
      months = (((to_date.year * 12) + to_date.month) - ((from_date.year * 12) + from_date.month))
      [months, 0].max
    end
  end
end
