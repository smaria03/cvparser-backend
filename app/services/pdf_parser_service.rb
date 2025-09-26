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

  def initialize(file)
    @file = file
    @tmp_pdf_path = Rails.root.join("tmp/cv_#{SecureRandom.hex}.pdf")
    @tmp_xml_path = @tmp_pdf_path.sub_ext('.xml')
  end

  def extract_text
    doc = doc_from_pdf
    ordered_text = text_nodes_from(doc).pluck(:text)
    {
      text: ordered_text.join("\n")
    }
  ensure
    cleanup_temp_files
  end

  def extract_sections
    doc = doc_from_pdf
    text_nodes = text_nodes_from(doc)

    section_hint = find_section_hint(text_nodes)
    return { section_hint: nil } unless section_hint

    font_id = section_hint[:font]
    section_blocks = build_section_blocks(text_nodes, font_id)

    {
      section_hint: section_hint, font_id: font_id, section_blocks: section_blocks
    }
  end

  def extract_relevant_data
    doc = doc_from_pdf
    text = extract_text[:text]
    sections = extract_sections

    {
      name: extract_name(doc), email: extract_email(text),
      experiences: extract_experiences(sections), current_job: extract_current_job(sections),
      total_experience_years: calculate_total_experience_years(sections),
      skills: extract_skills(sections)
    }
  end

  def recalculate_experience(experiences)
    total_months = experiences.sum do |exp|
      months_for_period(exp[:period])
    end

    years = total_months / 12
    months = total_months % 12

    "#{years}.#{months}y"
  end

  private

  def save_file_locally
    FileUtils.cp(@file.path, @tmp_pdf_path)
  end

  def generate_xml_with_poppler
    system('pdftohtml', '-xml', '-nodrm', @tmp_pdf_path.to_s, @tmp_xml_path.to_s)
    raise 'Failed to generate XML with pdftohtml' unless File.exist?(@tmp_xml_path)
  end

  def cleanup_temp_files
    FileUtils.rm_f(@tmp_pdf_path)
    FileUtils.rm_f(@tmp_xml_path)
  end

  def doc_from_pdf
    save_file_locally
    generate_xml_with_poppler
    Nokogiri::XML(File.read(@tmp_xml_path))
  end

  def text_nodes_from(doc)
    nodes = doc.xpath('//text').map do |node|
      {
        text: node.text.strip, font: node['font'].to_i,
        top: node['top'].to_i, left: node['left'].to_i
      }
    end

    nodes.reject { |n| n[:text].empty? }
  end

  def find_section_hint(text_nodes)
    experience_titles = ['experience', 'work experience', 'professional experience',
                         'employment history', 'career history', 'professional background',
                         'experiență profesională', 'istoric profesional', 'experiență de muncă',
                         'parcurs profesional', 'istoric angajări', 'experiență',]

    text_nodes.find do |n|
      experience_titles.include?(n[:text].strip.downcase)
    end
  end

  def build_section_blocks(text_nodes, font_id)
    section_blocks = []
    state = {
      buffer: nil,
      collecting: false,
      current_section_title: nil,
      section_text_nodes: []
    }

    text_nodes.each_with_index do |node, idx|
      next_node = text_nodes[idx + 1]

      if title_node?(node, font_id)
        process_title_node(node, next_node, font_id, state)
      elsif state[:collecting]
        process_section_content(node, next_node, font_id, state, section_blocks)
      end
    end

    if state[:collecting] && state[:current_section_title]
      section_blocks << build_section_block(state)
    end

    section_blocks
  end

  def extract_email(text)
    match = text.match(/\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/)
    match ? match[0] : 'Unknown'
  end

  def period_line?(text)
    normalized = normalize_period_text(text)
    normalized =~ PdfParserService::PERIOD_REGEX
  end

  def normalize_period_text(text)
    text.gsub(/[\u2013\u2014]/, '-')
        .gsub(/\b(\d)\s+(?=\d)/, '\1')
        .gsub(/\b([A-Z])\s+(?=[A-Z])/, '\1')
  end

  def title_node?(node, font_id)
    node[:font] == font_id
  end

  def handle_title_node(state, node)
    if state[:buffer]
      state[:buffer][:text] += ' ' + node[:text]
    else
      state[:buffer] = node.dup
    end
  end

  def build_section_block(state)
    {
      title: state[:current_section_title], text_nodes: state[:section_text_nodes]
    }
  end

  def reset_section_state(state)
    state[:current_section_title] = nil
    state[:section_text_nodes] = []
    state[:collecting] = false
  end

  def process_title_node(node, next_node, font_id, state)
    handle_title_node(state, node)

    return unless next_node.nil? || next_node[:font] != font_id

    state[:current_section_title] = state[:buffer][:text]
    state[:section_text_nodes] = []
    state[:collecting] = true
    state[:buffer] = nil
  end

  def process_section_content(node, next_node, font_id, state, section_blocks)
    state[:section_text_nodes] << node

    return unless next_node.nil? || next_node[:font] == font_id

    section_blocks << build_section_block(state)
    reset_section_state(state)
  end
end
