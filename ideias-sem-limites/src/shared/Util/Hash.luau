--!strict
-- Hash FNV-1a de 32 bits com aritmética exata em double (sem perda de precisão).

local Hash = {}

local TWO32 = 4294967296

function Hash.str(s: string): number
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		-- h * 16777619 == h * 2^24 + h * 403 (mod 2^32)
		h = (bit32.lshift(h, 24) + h * 403) % TWO32
	end
	return h
end

function Hash.combine(a: number, b: number): number
	return Hash.str(tostring(a) .. ":" .. tostring(b))
end

return Hash
