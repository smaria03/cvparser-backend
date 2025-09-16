module PdfParsing
  module NameExtractor
    def extract_name(doc)
      biggest_font_id = find_biggest_font_id(doc)
      return 'Unknown' unless biggest_font_id

      node = find_likely_name_node(doc, biggest_font_id)
      return 'Unknown' unless node

      text = node.text.strip.gsub("\u00A0", ' ')
      text.empty? ? 'Unknown' : text
    end

    def extract_font_sizes(doc)
      doc.xpath('//fontspec').each_with_object({}) do |font_node, hash|
        font_id = font_node['id'].to_i
        size = font_node['size'].to_f
        hash[font_id] = size
      end
    end

    private

    def find_biggest_font_id(doc)
      font_sizes = extract_font_sizes(doc)
      font_sizes.max_by { |_, size| size.to_f }&.first
    end

    def find_likely_name_node(doc, font_id)
      skip_words = %w[cv curriculum vitae resume]

      doc.xpath('//text')
         .select { |n| n['font'].to_i == font_id.to_i }
         .sort_by { |n| n['top'].to_i }
         .find do |node|
        text = node.text.strip.gsub("\u00A0", ' ')
        word_count = text.split.size
        word_count.between?(2, 4) && skip_words.none? { |w| text.downcase.include?(w) }
      end
    end
  end
end
