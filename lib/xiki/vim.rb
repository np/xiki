module XikiVim
  INDENT    = ' ' * 2
  INDENT_RE = /\A(\s*)/
  UNFOLDED_ITEM_RE = /\A(\s*)-/
  FOLDED_ITEM_RE = /\A(\s*)+/
end

%w{ vim/tree }.each do |lib|
  require File.expand_path("../#{lib}", __FILE__)
end

module XikiVim
  # go up until there is no whitespace
  # returns built path + absolute row of root
  def self.construct_path buffer
    path       = ""
    offset     = 0
    line       = buffer.line_number
    cur_id_lvl = 1e10

    # build path as long as line starts with whitespaces
    until (match = buffer[line + offset].match(/\A(\s+)/)).nil?
      line_id_lvl = match[1].length

      # check if we reached a parent, and append it to path
      if line_id_lvl < cur_id_lvl
        path = sanitize(buffer[line + offset]) + path
        cur_id_lvl = line_id_lvl
      end
      offset -= 1
    end
    path = sanitize(buffer[line + offset]) + "/" + path

    return path
  end

  # FIXME error handling on shell out
  def self.take_action buffer, path
    # NP: I don't see the point, and it also introduce issues
    #     since not all lines have to be menu items.
    # ensure_format buffer

    if unfolded? buffer.line
      buffer[buffer.line_number] = buffer.line.gsub(UNFOLDED_ITEM_RE, '\1+')
      block(buffer, true)
    else
      # check cache
      buffer[buffer.line_number] = buffer.line.gsub(/\+/, '-')
      xiki_resp = %x{ xiki "#{path}" }
      t = Tree.new xiki_resp
      t.render buffer
    end
  end

  protected
  def self.unfolded? line
    !!(line =~ UNFOLDED_ITEM_RE)
  end

  def self.sanitize line
    line.rstrip.gsub(/\A\s*[+-]?\s*/, '')
  end

  # get the sub-block (indentation-wise), optionally delete it
  def self.block vimbuffer, do_delete
    id_level = vimbuffer.line[INDENT_RE, 1]
    buffer   = ""
    i        = vimbuffer.line_number + 1

    while id_level < vimbuffer[i][INDENT_RE, 1]
      buffer << vimbuffer[i]
      do_delete ? vimbuffer.delete(i) : i += 1
    end

    return buffer
  end

  # unused
  def self.ensure_format buffer
    char = buffer.line.lstrip[0].chr
    if char != '-' && char != '+'
      buffer.line = '+ ' + buffer.line
    end
  end
end
