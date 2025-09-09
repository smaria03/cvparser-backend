module PdfParsing
  module ExperienceExtractor
    def extract_raw_experiences(doc)
      text_nodes = extract_text_nodes(doc)

      text_nodes.each_with_index.with_object([]) do |(node, idx), blocks|
        next unless period_line?(node[:text])

        experience = build_experience_block(text_nodes, idx)
        blocks << experience if experience
      end
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

    def period_line?(text)
      text =~ PdfParserService::PERIOD_REGEX
    end

    def build_experience_block(nodes, idx)
      period  = nodes[idx][:text]
      company = nodes[idx - 1]&.[](:text)
      title   = nodes[idx - 2]&.[](:text)

      return nil if [company, title].any?(&:blank?)

      {
        title: title,
        company: company,
        period: period
      }
    end
  end
end
