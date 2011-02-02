# -*- coding: utf-8 -*-

require 'digest/md5'

$YABITZ_OPETAG_SEED_INT = 0

module Yabitz ; end
module Yabitz::OpeTagGenerator
  LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'

  def self.alphabetic_number(num, scale=4)
    target = num % (LETTERS.size ** scale)
    result = ''
    s = scale - 1
    while s >= 0
      base = LETTERS.size ** s
      result += LETTERS[target / base]
      target = (target % base)
      s += -1
    end
    result
  end

  def self.match(tag)
    if tag and tag =~ /\A((20\d{2})(\d{2})(\d{2})(\d{2})(\d{2})[A-Za-z]{5})\Z/ and
        $2.to_i >= 2010 and $2.to_i < 2100 and
        $3.to_i >= 1 and $3.to_i <= 12 and
        $4.to_i >= 1 and $4.to_i <= 31 and
        $5.to_i >= 0 and $5.to_i <= 23 and
        $6.to_i >= 0 and $6.to_i <= 59
      $1
    else
      nil
    end
  end

  def self.generate
    $YABITZ_OPETAG_SEED_INT += 1
    now = Time.now.localtime
    seed = Digest::MD5.digest(now.to_s + rand().to_s + now.usec.to_s + $YABITZ_OPETAG_SEED_INT.to_s + now.object_id.to_s)
    suf = self.alphabetic_number(seed[0,4].unpack("L*").first, 5)
    now.strftime('%Y%m%d%H%M') + suf
  end
end
