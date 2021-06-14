require "bigdecimal"

class BigDecimal
  def to_money_string
    truncate.to_s + "." + sprintf("%02d", (frac.abs * 100).truncate)
  end
end

class String
  def q
    '"' + self + '"'
  end
  
  def rp
    gsub('\\', '/')
  end

  def wp
    gsub('/', '\\')
  end

  def wpq
    '"' + gsub('/', '\\') + '"'
  end

  # colors
  def cyan
    "#{ESC}1m#{ESC}36m" + self + "#{NND}"
  end

  def green
    "#{ESC}1m#{ESC}32m" + self + "#{NND}"
  end

  def red
    "#{ESC}1m#{ESC}31m" + self + "#{NND}"
  end

private

  ESC = "\e["
  NND = "#{ESC}0m"
end
