--!strict
-- Correção simples de digitação: distância de Damerau–Levenshtein (variante OSA)
-- com corte antecipado. O vocabulário é agrupado por tamanho, então cada palavra
-- desconhecida é comparada só com candidatos de tamanho parecido.

local Fuzzy = {}

function Fuzzy.distance(a: string, b: string, maxDist: number): number
	local la, lb = #a, #b
	if math.abs(la - lb) > maxDist then
		return maxDist + 1
	end
	if a == b then
		return 0
	end
	local prevPrev: { number } = {}
	local prev: { number } = {}
	for j = 0, lb do
		prev[j] = j
	end
	for i = 1, la do
		local cur: { number } = { [0] = i }
		local rowMin = i
		local ai = string.byte(a, i)
		for j = 1, lb do
			local bj = string.byte(b, j)
			local cost = if ai == bj then 0 else 1
			local v = math.min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost)
			if i > 1 and j > 1 and ai == string.byte(b, j - 1) and string.byte(a, i - 1) == bj then
				v = math.min(v, prevPrev[j - 2] + 1)
			end
			cur[j] = v
			if v < rowMin then
				rowMin = v
			end
		end
		if rowMin > maxDist then
			return maxDist + 1
		end
		prevPrev = prev
		prev = cur
	end
	return prev[lb]
end

-- tolerância conforme o tamanho da palavra
function Fuzzy.tolerance(word: string): number
	local n = #word
	if n < 4 then
		return 0
	elseif n <= 6 then
		return 1
	else
		return 2
	end
end

export type Index = { byLength: { [number]: { string } } }

function Fuzzy.buildIndex(words: { string }): Index
	local byLength: { [number]: { string } } = {}
	local seen: { [string]: boolean } = {}
	for _, w in words do
		if #w >= 3 and not seen[w] then
			seen[w] = true
			local bucket = byLength[#w]
			if not bucket then
				bucket = {}
				byLength[#w] = bucket
			end
			table.insert(bucket, w)
		end
	end
	for _, bucket in byLength do
		table.sort(bucket)
	end
	return { byLength = byLength }
end

-- melhor candidato; empate resolvido pela ordem alfabética (determinístico)
function Fuzzy.best(index: Index, word: string): (string?, number)
	local tol = Fuzzy.tolerance(word)
	if tol == 0 then
		return nil, math.huge
	end
	local bestWord: string? = nil
	local bestDist = tol + 1
	for len = #word - tol, #word + tol do
		local bucket = index.byLength[len]
		if bucket then
			for _, cand in bucket do
				-- exige a mesma primeira letra: reduz falsos positivos
				if string.byte(cand, 1) == string.byte(word, 1) then
					local d = Fuzzy.distance(word, cand, bestDist - 1)
					if d < bestDist then
						bestDist = d
						bestWord = cand
					end
				end
			end
		end
	end
	if bestWord then
		return bestWord, bestDist
	end
	return nil, math.huge
end

return Fuzzy
