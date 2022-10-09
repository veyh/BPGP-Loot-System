local _, BPGP = ...

local lib = {}
BPGP.RegisterLibrary("Storage", lib)

local Common = BPGP.GetLibrary("Common")
local Encryption = BPGP.GetLibrary("Encryption")

local assert, ipairs, tostring = assert, ipairs, tostring
local strbyte, strchar = strbyte, string.char
local tinsert, tremove, tconcat = tinsert, tremove, table.concat

local codePage = {}
local unwritableChars = {[10]=true, [13]=true, [124]=true} -- '\n', '\r', '|'
for byte1 = 1, 127 do -- 0 is unwritable
  if not unwritableChars[byte1] then
    tinsert(codePage, {char = strchar(byte1), byte1 = byte1})
  end
end
for byte1 = 194, 239 do -- 240-244 is unwritable
  for byte2 = 128, 191 do
    tinsert(codePage, {char = strchar(byte1, byte2), byte1 = byte1, byte2 = byte2})
  end
end
assert(#codePage == 3068, "Invalid codepage size "..tostring(#codePage)..", please contact developer!")

function lib:GetCodepage()
  return codePage
end

local encoder, decoder, oneByteDecoder, twoByteDecoder = {}, {}, {}, {}
for i, charData in ipairs(codePage) do
  encoder[i - 1] = charData.char
  decoder[charData.char] = i - 1
  if charData.byte2 then
    if not twoByteDecoder[charData.byte1] then twoByteDecoder[charData.byte1] = {} end
    twoByteDecoder[charData.byte1][charData.byte2] = i - 1
  else
    oneByteDecoder[charData.byte1] = i - 1
  end
end

function lib:EncodeBase3068(int)
  return encoder[int]
end

function lib:DecodeBase3068(base3068)
  return decoder[base3068]
end

function lib:ParseByteString(str)
  local byteString, encodedBytes, cachedByte = {strbyte(str, 1, #str)}, {}, nil
  for i = 1, #byteString do
    if cachedByte then
      tinsert(encodedBytes, twoByteDecoder[cachedByte][byteString[i]])
      cachedByte = nil
    else
      if byteString[i] > 127 then
        cachedByte = byteString[i]
      else
        tinsert(encodedBytes, oneByteDecoder[byteString[i]])
      end
    end
  end
  return encodedBytes
end

function lib:EncryptBytes(bytes, byteKey)
  local encryptedBytes = {}
  for i = 1, #bytes do
    local byte = bytes[i] + byteKey[i]
    if byte > 3067 then
      byte = byte - 3068
    end
    tinsert(encryptedBytes, byte)
  end
  return encryptedBytes
end

function lib:DecryptBytes(encryptedBytes, byteKey)
  local bytes = {}
  for i = 1, #encryptedBytes do
    local byte = encryptedBytes[i] - byteKey[i]
    if byte < 0 then
      byte = byte + 3068
    end
    tinsert(bytes, byte)
  end
  return bytes
end

function lib:Encode(state, key, bytes)
  if #bytes == 0 then return end
  local checkSum = 0
  for i = 1, #bytes do
    local byte = bytes[i]
    assert(byte >= 0, "Cannot encode negative byte "..tostring(byte).." at pos "..tostring(i))
    assert(byte < 3068, "Cannot encode invalid byte "..tostring(byte).." at pos "..tostring(i))
    checkSum = checkSum + byte
  end
  checkSum = math.floor(checkSum / #bytes + state) % 3000
  tinsert(bytes, checkSum)
  
  local byteKey = Encryption:GetByteKey(key)
  local encryptedBytes = lib:EncryptBytes(bytes, byteKey)
  
  local encodedChars = {}
  for i = 1, #encryptedBytes do
    tinsert(encodedChars, encoder[encryptedBytes[i]])
  end
  
  return tconcat(encodedChars, "")
end

function lib:Decode(state, key, encodedChars)
  if not encodedChars or #encodedChars == 0 then return end
  local encodedBytes = lib:ParseByteString(encodedChars)

  local byteKey = Encryption:GetByteKey(key)
  local decryptedBytes = lib:DecryptBytes(encodedBytes, byteKey)
  
  local decryptedBytesLen = #decryptedBytes
  local checkSum = 0
  for i = 1, decryptedBytesLen - 1 do
    checkSum = checkSum + decryptedBytes[i]
  end
  checkSum = math.floor((checkSum / (decryptedBytesLen - 1) + state)) % 3000
  if checkSum ~= decryptedBytes[decryptedBytesLen] then return end
  tremove(decryptedBytes, decryptedBytesLen)
  return decryptedBytes
end