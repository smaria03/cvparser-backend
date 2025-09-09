module PdfParsing
  module SkillsExtractor
    def extract_skills(doc)
      text_nodes = extract_text_nodes(doc)
      index = find_skills_index(text_nodes)
      return [] unless index

      skill_lines = extract_skill_lines(text_nodes, index)
      format_skills(skill_lines)
    end

    private

    def extract_text_nodes(doc)
      doc.xpath('//text').map do |node|
        {
          text: node.text.strip,
          top: node['top'].to_i,
          left: node['left'].to_i,
          font: node['font'].to_i
        }
      end
    end

    def find_skills_index(nodes)
      nodes.index { |n| n[:text].strip.downcase == 'skills' }
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

    def format_skills(lines)
      lines
        .join(' ')
        .split(/[,;\u2022\n]/)
        .map(&:strip)
        .reject(&:empty?)
        .uniq
    end
  end
end
