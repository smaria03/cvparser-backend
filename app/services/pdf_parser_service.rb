# frozen_string_literal: true

require 'nokogiri'
require 'securerandom'
require 'date'

require_relative 'pdf_parsing/name_extractor'
require_relative 'pdf_parsing/skills_extractor'
require_relative 'pdf_parsing/experience_extractor'

class PdfParserService
  include PdfParsing::NameExtractor
  include PdfParsing::SkillsExtractor
  include PdfParsing::ExperienceExtractor

  PERIOD_REGEX = /
  (
    (Jan(uary)?|Feb(ruary)?|Mar(ch)?|Apr(il)?|May|Jun(e)?|
     Jul(y)?|Aug(ust)?|Sep(tember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?)
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
     Jul(y)?|Aug(ust)?|Sep(tember)?|Oct(ober)?|Nov(ember)?|Dec(ember)?)
    [\s\/\-\.]?
    \d{4}
  |
    \d{1,2}[\/\-]\d{4}
  |
    \d{4}
  )
/ix.freeze

  def initialize(file)
    @file = file
    @tmp_pdf_path = Rails.root.join("tmp/cv_#{SecureRandom.hex}.pdf")
    @tmp_xml_path = @tmp_pdf_path.sub_ext('.xml')
  end

  def extract_text
    save_file_locally
    generate_xml_with_poppler
    doc = Nokogiri::XML(File.read(@tmp_xml_path))

    ordered_text = extract_ordered_text(doc)
    experiences = extract_raw_experiences(doc)

    {
      name: extract_name(doc),
      email: extract_email(ordered_text.join("\n")),
      experiences: experiences,
      current_job: extract_current_job(experiences),
      total_experience_years: calculate_total_experience_years(experiences),
      skills: extract_skills(doc),
      text: ordered_text.join("\n")
    }
  ensure
    cleanup_temp_files
  end

  def extract_ordered_text(doc)
    texts_by_column = Hash.new { |h, k| h[k] = [] }

    doc.xpath('//text').each do |node|
      text = node.text.strip
      next if text.blank?

      col_key = (node['left'].to_i / 50) * 50
      texts_by_column[col_key] << { top: node['top'].to_i, text: text }
    end

    texts_by_column.sort_by { |left, _| left }
                   .flat_map { |_, lines| lines.sort_by { |l| l[:top] }.map { |l| l[:text] } }
  end

  private

  def extract_email(text)
    match = text.match(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/)
    match ? match[0] : 'Unknown'
  end

  def save_file_locally
    File.binwrite(@tmp_pdf_path, @file.download)
  end

  def generate_xml_with_poppler
    system('pdftohtml', '-xml', '-nodrm', @tmp_pdf_path.to_s, @tmp_xml_path.to_s)
    raise 'Failed to generate XML with pdftohtml' unless File.exist?(@tmp_xml_path)
  end

  def cleanup_temp_files
    FileUtils.rm_f(@tmp_pdf_path)
    FileUtils.rm_f(@tmp_xml_path)
  end

  def extract_current_job(experiences)
    experiences.find { |exp| exp[:period].downcase.match?(/present|prezent|current/) }
  end

  def calculate_total_experience_years(experiences)
    total_months = experiences.sum do |exp|
      next 0 unless exp[:period] =~ PERIOD_REGEX

      from_str, to_str = exp[:period].split(/-+/).map(&:strip)
      from_date = parse_date_string(from_str)
      to_date = parse_date_string(to_str) || Time.zone.today

      next 0 unless from_date

      months = ((to_date.year * 12) + to_date.month) - ((from_date.year * 12) + from_date.month)
      [months, 0].max
    end

    (total_months / 12.0).round(1)
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
end
