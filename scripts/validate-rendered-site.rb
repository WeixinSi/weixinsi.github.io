# Run after `bundle exec jekyll build --strict_front_matter`.
require 'nokogiri'
require 'uri'

root = File.expand_path(ARGV.fetch(0, '_site'))
origin = 'https://weixinsi.github.io'
pages = %w[/ /team/ /publications/ /talks/ /teaching/ /gallery/ /more/ /research/ /terms/ /sitemap/]
excluded = %w[docs scripts markdown_generator talkmap talkmap.py files/bibtex1.bib files/paper1.pdf files/paper2.pdf files/paper3.pdf files/slides1.pdf files/slides2.pdf files/slides3.pdf]
errors = []
documents = {}
checked_resources = {}

resolve_file = lambda do |path|
  relative = URI::DEFAULT_PARSER.unescape(path).delete_prefix('/')
  resolved = File.expand_path(relative, root)
  raise "Path escapes site output: #{path}" unless resolved == root || resolved.start_with?(root + File::SEPARATOR)
  File.directory?(resolved) ? File.join(resolved, 'index.html') : resolved
end

pages.each do |path|
  file = resolve_file.call(path)
  unless File.file?(file)
    errors << "Missing public page: #{path}"
    next
  end
  doc = documents[file] = Nokogiri::HTML(File.read(file, encoding: 'UTF-8'))
  errors << "Missing document title: #{path}" if doc.at_css('title')&.text.to_s.strip.empty?
  errors << "Expected one page heading: #{path}" unless doc.css('h1').size == 1
  duplicates = doc.css('[id]').map { |node| node['id'] }.tally.select { |_, count| count > 1 }.keys
  errors << "Duplicate IDs on #{path}: #{duplicates.join(', ')}" unless duplicates.empty?
  errors << "Missing image alt text: #{path}" if doc.css('img').any? { |node| node['alt'].to_s.empty? }
  errors << "Escaped formatting tags in visible text: #{path}" if doc.text.match?(%r{</?(?:sup|strong|em)>})
  doc.css('button, [role="button"]').each do |button|
    label = button['aria-label'].to_s.strip
    label = button.text.strip if label.empty?
    errors << "Unnamed button: #{path}" if label.empty? && button['aria-labelledby'].to_s.empty?
    if button['role'] == 'button' && button.name != 'button' && button['href'].to_s.empty? && button['tabindex'].to_s != '0'
      errors << "Button cannot receive keyboard focus: #{path}"
    end
  end

  doc.css('a[href], img[src], script[src], link[href]').each do |node|
    raw = node['href'] || node['src']
    next if raw.to_s.empty? || raw.match?(/\A(?:mailto:|tel:|data:|javascript:)/i)
    begin
      uri = URI.join(origin + path, raw.gsub(' ', '%20'))
      next unless uri.host == 'weixinsi.github.io'
      target = resolve_file.call(uri.path)
      unless File.file?(target)
        errors << "Broken internal resource on #{path}: #{raw}"
        next
      end
      checked_resources[uri.path] = true
      if uri.fragment && target.end_with?('.html')
        target_doc = documents[target] ||= Nokogiri::HTML(File.read(target, encoding: 'UTF-8'))
        fragment = URI::DEFAULT_PARSER.unescape(uri.fragment)
        errors << "Missing anchor on #{path}: #{raw}" unless target_doc.css('[id], a[name]').any? { |entry| entry['id'] == fragment || entry['name'] == fragment }
      end
    rescue URI::InvalidURIError, ArgumentError => error
      errors << "Invalid URL on #{path}: #{raw} (#{error.message})"
    end
  end
end

excluded.each do |path|
  errors << "Development or sample content was published: #{path}" if File.exist?(File.join(root, path))
end

sitemap_file = File.join(root, 'sitemap.xml')
if File.file?(sitemap_file)
  sitemap = Nokogiri::XML(File.read(sitemap_file)).remove_namespaces!
  sitemap.css('loc').each do |node|
    path = URI(node.text).path.delete_prefix('/')
    errors << "Unwanted sitemap entry: #{node.text}" if excluded.any? { |entry| path == entry || path.start_with?(entry + '/') }
  end
else
  errors << 'Missing XML sitemap'
end

site_map = documents[resolve_file.call('/sitemap/')]
if site_map
  errors << '404 page is listed in the HTML sitemap' if site_map.css('.archive__item a').any? { |node| node['href'].to_s.end_with?('/404.html') }
  errors << 'Empty Posts section in the HTML sitemap' if site_map.css('h2').any? { |node| node.text.strip == 'Posts' } && Dir.glob(File.join(root, 'posts', '**', '*.html')).empty?
end

if errors.empty?
  puts "Rendered-site validation passed: #{pages.size} public pages, #{checked_resources.size} unique internal resources, anchors, and publication exclusions."
else
  warn errors.uniq.join("\n")
  exit 1
end
