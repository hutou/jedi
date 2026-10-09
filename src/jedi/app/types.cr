module Jedi
  #
  # types
  #

  alias PkId = Int64

  enum SimulationMode
    None
    FromOperation
    FromSeed
  end

  #
  # constants
  #
  DATETIME_VALIDATE = /^(\d{4})\-(0?[1-9]|1[012])\-(0?[1-9]|[12][0-9]|3[01]) ([0-1][0-9]|[2][0-3]):([0-5][0-9]):([0-5][0-9])$/
  DATE_VALIDATE     = /^(\d{4})\-(0?[1-9]|1[012])\-(0?[1-9]|[12][0-9]|3[01])$/
  DATE_FORMAT       = "^\\d{4}-\\d{2}-\\d{2}$"
  TIME_FORMAT       = "^\\d{2}:\\d{2}:\\d{2}$"

  DECIMAL                  = /\A[+-]?\d+(\.\d+)?\z/
  NON_NEGATIVE_DECIMAL     = /\A\+?\d+(\.\d+)?\z/
  POSITIVE_DECIMAL         = /\A\+?(?:\d*[1-9]\d*(?:\.\d+)?|0+\.\d*[1-9]\d*)\z/
  DECIMAL_PCT              = /\A[+-]?\d+(\.\d+)?%?\z/
  NON_NEGATIVE_DECIMAL_PCT = /\A\+?\d+(\.\d+)?%?\z/
  POSITIVE_DECIMAL_PCT     = /\A\+?(?:\d*[1-9]\d*(?:\.\d+)?|0+\.\d*[1-9]\d*)%?\z/
  ALPHANUM                 = /\A[A-Za-z]\w+\z/
  INTEGER                  = /\A[+-]?\d+\z/
  NON_NEGATIVE_INTEGER     = /\A\+?\d+\z/
  POSITIVE_INTEGER         = /\A\+?0*[1-9]\d*\z/

  COLOR_INFO  = :green
  COLOR_WARN  = :yellow
  COLOR_ERROR = :light_red

  # date format ISO 8601: YYYY-MM-DD
  DATE_FIELDS = "%Y-%m-%d"
  # time format ISO 8601: HH:MM:SS
  TIME_FIELDS     = "%H:%M:%S"
  DATETIME_FIELDS = DATE_FIELDS + " " + TIME_FIELDS

  ESEP = '='
  CSEP = ':'

  # Scale class, defaults
  KEYWORDS = ["vr", "np", "sr", "nn", "mi", "kc", "ks", "ki", "kb", "kd", "mg"]

  KC_MIN = 0.05
  KC_MAX =  3.0

  KC_DIFF_MIN = 0.05
  KS_DIFF_MIN = 0.05

  KS_MIN = 0.0
  KS_MAX = 9.0

  KI_MIN =  0.0
  KI_MAX = 0.39

  KB_MIN = 0
  KB_MAX = 1

  KD_MIN = -0.39
  KD_MAX =  0.39

  VR_MIN = 0.04
  VR_MAX = 0.39

  NP_MIN = 2
  NP_MAX = 6

  NN_MIN = 2
  NN_MAX = 6

  SR_MIN = 0.0
  SR_MAX = 0.8

  MI_MIN = 1.2
  MI_MAX = 7.0
end
