local _, BPGP = ...

local lib = {}
BPGP.RegisterLibrary("Encryption", lib)

local Common = BPGP.GetLibrary("Common")

local pairs = pairs
local strbyte, strchar, strlen = strbyte, string.char, strlen
local tinsert, tconcat = tinsert, table.concat
local band, lshift, rshift, bxor = bit.band, bit.lshift, bit.rshift, bit.bxor

local base64 = {}
local extract = function( v, from, width )
  return band(rshift(v, from), lshift(1, width) - 1)
end

function lib:makeencoder(s62, s63, spad)
	local encoder = {}
	for b64code, char in pairs{[0]='A','B','C','D','E','F','G','H','I','J',
		'K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y',
		'Z','a','b','c','d','e','f','g','h','i','j','k','l','m','n',
		'o','p','q','r','s','t','u','v','w','x','y','z','0','1','2',
		'3','4','5','6','7','8','9',s62 or '+',s63 or'/',spad or'='} do
		encoder[b64code] = char:byte()
	end
	return encoder
end

function lib:makedecoder(s62, s63, spad)
	local decoder = {}
	for b64code, charcode in pairs( lib:makeencoder( s62, s63, spad )) do
		decoder[charcode] = b64code
	end
	return decoder
end

local DEFAULT_ENCODER = lib:makeencoder()
local DEFAULT_DECODER = lib:makedecoder()

function lib:EncodeBase64(str, encoder, usecaching)
  if not str or str == "" then return nil end
	encoder = encoder or DEFAULT_ENCODER
	local t, k, n = {}, 1, #str
	local lastn = n % 3
	local cache = {}
	for i = 1, n-lastn, 3 do
		local a, b, c = str:byte( i, i+2 )
		local v = a*0x10000 + b*0x100 + c
		local s
		if usecaching then
			s = cache[v]
			if not s then
				s = strchar(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[extract(v,0,6)])
				cache[v] = s
			end
		else
			s = strchar(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[extract(v,0,6)])
		end
		t[k] = s
		k = k + 1
	end
	if lastn == 2 then
		local a, b = str:byte( n-1, n )
		local v = a*0x10000 + b*0x100
		t[k] = strchar(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[extract(v,6,6)], encoder[64])
	elseif lastn == 1 then
		local v = str:byte( n )*0x10000
		t[k] = strchar(encoder[extract(v,18,6)], encoder[extract(v,12,6)], encoder[64], encoder[64])
	end
	return tconcat( t )
end

function lib:DecodeBase64(str, decoder, usecaching)
  local b64 = string.match(str, '[%w%+/=]+')
  if not b64 then return nil end
  if strlen(b64) % 4 ~= 0 then return nil end
  
	decoder = decoder or DEFAULT_DECODER
	local pattern = '[^%w%+%/%=]'
	if decoder then
		local s62, s63
		for charcode, b64code in pairs( decoder ) do
			if b64code == 62 then s62 = charcode
			elseif b64code == 63 then s63 = charcode
			end
		end
		pattern = ('[^%%w%%%s%%%s%%=]'):format( strchar(s62), strchar(s63) )
	end
	b64 = b64:gsub( pattern, '' )
	local cache = usecaching and {}
	local t, k = {}, 1
	local n = #b64
	local padding = b64:sub(-2) == '==' and 2 or b64:sub(-1) == '=' and 1 or 0
	for i = 1, padding > 0 and n-4 or n, 4 do
		local a, b, c, d = b64:byte( i, i+3 )
		local s
		if usecaching then
			local v0 = a*0x1000000 + b*0x10000 + c*0x100 + d
			s = cache[v0]
			if not s then
				local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40 + decoder[d]
				s = strchar( extract(v,16,8), extract(v,8,8), extract(v,0,8))
				cache[v0] = s
			end
		else
			local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40 + decoder[d]
			s = strchar( extract(v,16,8), extract(v,8,8), extract(v,0,8))
		end
		t[k] = s
		k = k + 1
	end
	if padding == 1 then
		local a, b, c = b64:byte( n-3, n-1 )
		local v = decoder[a]*0x40000 + decoder[b]*0x1000 + decoder[c]*0x40
		t[k] = strchar( extract(v,16,8), extract(v,8,8))
	elseif padding == 2 then
		local a, b = b64:byte( n-3, n-2 )
		local v = decoder[a]*0x40000 + decoder[b]*0x1000
		t[k] = strchar( extract(v,16,8))
	end
	return tconcat( t )
end

local byteCache = {}

function lib:MakeByteKey(key, len)
  local byteKey = {strbyte(key, 1, #key)}
  for i = 1, len - #byteKey do
    tinsert(byteKey, byteKey[i])
  end
  return byteKey
end

function lib:GetByteKey(key, len)
  local byteKey = byteCache[key]
  if not byteKey then 
    byteKey = lib:MakeByteKey(key, len or 64)
    byteCache[key] = byteKey
  end
  return byteKey
end

function lib:RunXOR(str, key)
  local byteKey = lib:GetByteKey(key)
  local bytes = {strbyte(str, 1, #str)}
  local xor = {}
  for i = 1, #bytes do
    tinsert(xor, strchar(bxor(bytes[i], byteKey[i])))
  end
  return tconcat(xor, "")
end

function lib:GetChecksum(data)
  local sum = 65535
  local d
  for i = 1, #data do
    d = strbyte(data, i)
    sum = lib:ByteCRC(sum, d)
  end
  return sum
end

function lib:ByteCRC(sum, data)
  sum = bxor(sum, data)
  for i = 0, 7 do
    if (band(sum, 1) == 0) then
      sum = rshift(sum, 1)
    else
      sum = bxor(rshift(sum, 1), 0xA001) 
    end
  end
  return sum
end

function lib:Encode(str, key)
  if not str or str == "" then return "" end
  return lib:EncodeBase64(lib:RunXOR(str, key))
end

function lib:Decode(str, key)
  if not str or str == "" then return "" end  
  return lib:RunXOR(lib:DecodeBase64(str), key)
end