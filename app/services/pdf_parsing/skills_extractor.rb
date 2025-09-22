module PdfParsing
  module SkillsExtractor
    def extract_skills(sections)
      skills_from_sections = extract_skills_from_sections(sections)
      return skills_from_sections unless skills_from_sections.empty?

      doc = doc_from_pdf
      nodes = text_nodes_from(doc)

      index = find_skills_index(nodes, sections)
      return [] unless index

      lines = extract_skill_lines(nodes, index)

      lines
        .join(', ')
        .gsub(/\b[^:,]+?:\s*/, '')
        .split(/[,;•\n]/)
        .map(&:strip)
        .reject(&:empty?)
        .uniq
        .join(', ')
        .gsub(/[\s,\.]+$/, '')
    end

    private

    def extract_skills_from_sections(sections)
      skill_keywords = [
        'skills', 'technologies', 'competencies', 'tools',
        'tehnologii', 'competențe', 'competențe tehnice',
        'stack', 'tech stack'
      ]

      section = sections[:section_blocks].find do |s|
        title = s[:title].strip.downcase
        skill_keywords.any? { |kw| title.include?(kw) }
      end

      return '' unless section

      lines = section[:text_nodes].pluck(:text)

      lines
        .join(', ')
        .gsub(/\b[^:,]+?:\s*/, '')
        .split(/[,;•\n]/)
        .map(&:strip)
        .reject(&:empty?)
        .uniq
        .join(', ')
        .gsub(/[\s,\.]+$/, '')
    end

    def find_skills_index(nodes, sections)
      experience_nodes = experience_nodes(sections)

      index = nodes.index do |n|
        text = n[:text].strip.downcase
        (text.include?('skills') || text.include?('technologies')) && experience_nodes.exclude?(n)
      end
      return index if index

      nodes.index do |n|
        text = n[:text].strip.downcase
        (text.include?('skills') || text.include?('technologies')) && experience_nodes.include?(n)
      end
    end

    def experience_nodes(sections)
      title = sections[:section_hint][:text].strip.downcase
      section = sections[:section_blocks].find { |s| s[:title].strip.downcase == title }
      section ? section[:text_nodes].to_set : Set.new
    end

    def extract_skill_lines(nodes, index)
      first = nodes[index + 1]
      return [] unless first

      font_id = first[:font]
      lines = [first[:text]]

      nodes[(index + 2)..].each do |node|
        break unless node[:font] == font_id

        lines << node[:text]
      end

      lines
    end
  end
end
